import AppKit
import Foundation
import IOKit.ps
import LidAwakeShared

@MainActor
final class AppModel: ObservableObject {
  enum Mode: Equatable {
    case setupRequired
    case normal
    case starting
    case active
    case safetyStopped(String)
    case error(String)
  }

  @Published private(set) var mode: Mode = .normal
  @Published private(set) var helperStatus: HelperStatus?
  @Published private(set) var chatGPTIsRunning = false

  var helperIsReady: Bool {
    helperStatus?.schemaVersion == AppConstants.helperStatusSchemaVersion
  }

  private var heartbeatTask: Task<Void, Never>?
  private var statusTask: Task<Void, Never>?
  private var activityToken: NSObjectProtocol?
  private let leaseURL = LidAwakePaths.leaseFile(homeDirectory: NSHomeDirectory())
  private let statusURL = LidAwakePaths.statusFile(homeDirectory: NSHomeDirectory())

  init() {
    mode = Self.helperIsInstalled ? .normal : .setupRequired
    statusTask = Task { [weak self] in
      while !Task.isCancelled {
        self?.refreshStatus()
        try? await Task.sleep(for: .seconds(1))
      }
    }
  }

  deinit {
    heartbeatTask?.cancel()
    statusTask?.cancel()
  }

  func toggle() async {
    switch mode {
    case .active, .starting:
      await stop()
    case .setupRequired, .normal, .safetyStopped, .error:
      await start()
    }
  }

  func start() async {
    if !Self.helperIsInstalled
      || helperStatus?.schemaVersion != AppConstants.helperStatusSchemaVersion
    {
      do {
        try PrivilegedInstaller.install()
      } catch {
        mode = .error(L10n.format("error.setup_failed_format", error.localizedDescription))
        return
      }
    }

    guard Self.isACConnected() else {
      mode = .safetyStopped(L10n.text("safety.connect_power"))
      return
    }

    mode = .starting
    beginActivity()
    writeLease(enabled: true)
    heartbeatTask?.cancel()
    heartbeatTask = Task { [weak self] in
      while !Task.isCancelled {
        self?.writeLease(enabled: true)
        try? await Task.sleep(for: .seconds(AppConstants.heartbeatInterval))
      }
    }

    var helperFailure: HelperFailure?
    for _ in 0..<24 {
      refreshStatus()
      if helperStatus?.isBlockingSleep == true {
        mode = .active
        return
      }
      if helperStatus?.reason == .helperError {
        helperFailure = helperStatus?.failure
      }
      try? await Task.sleep(for: .milliseconds(500))
    }
    await stop()
    mode = .error(
      localizedHelperFailure(helperFailure).map {
        L10n.format("error.enable_failed_detail_format", $0)
      }
        ?? L10n.text("error.enable_failed")
    )
  }

  func stop() async {
    heartbeatTask?.cancel()
    heartbeatTask = nil
    writeLease(enabled: false)
    endActivity()
    for _ in 0..<8 {
      refreshStatus()
      if helperStatus?.isBlockingSleep != true {
        mode = Self.helperIsInstalled ? .normal : .setupRequired
        return
      }
      try? await Task.sleep(for: .milliseconds(500))
    }
    mode = .error(L10n.text("error.normal_mode_confirmation"))
  }

  nonisolated func disableLeaseImmediately() {
    let lease = LeaseRecord(
      enabled: false,
      ownerPID: getpid(),
      ownerExecutable: "LidAwakeApp",
      updatedAt: Date()
    )
    try? SecureJSONFile.write(lease, to: LidAwakePaths.leaseFile(homeDirectory: NSHomeDirectory()))
  }

  private func writeLease(enabled: Bool) {
    let lease = LeaseRecord(
      enabled: enabled,
      ownerPID: getpid(),
      ownerExecutable: "LidAwakeApp",
      updatedAt: Date()
    )
    do {
      try SecureJSONFile.write(lease, to: leaseURL)
    } catch {
      mode = .error(L10n.format("error.state_file_write_format", error.localizedDescription))
    }
  }

  private func refreshStatus() {
    chatGPTIsRunning = !NSRunningApplication.runningApplications(
      withBundleIdentifier: "com.openai.codex"
    ).isEmpty
    guard let status = try? SecureJSONFile.read(HelperStatus.self, from: statusURL),
      Date().timeIntervalSince(status.updatedAt) <= 10
    else {
      helperStatus = nil
      if mode == .active {
        mode = .error(L10n.text("error.helper_unresponsive"))
      }
      return
    }
    helperStatus = status
    if status.schemaVersion != AppConstants.helperStatusSchemaVersion {
      switch mode {
      case .active, .starting:
        mode = .error(L10n.text("error.helper_update_required"))
      case .setupRequired:
        break
      case .normal, .safetyStopped, .error:
        mode = .setupRequired
      }
      return
    }
    if mode == .active, !status.isBlockingSleep {
      let message: String =
        switch status.reason {
        case .batteryPower: L10n.text("safety.power_disconnected")
        case .thermalPressure: L10n.text("safety.thermal_pressure")
        default: L10n.text("safety.conditions_failed")
        }
      heartbeatTask?.cancel()
      heartbeatTask = nil
      endActivity()
      mode = .safetyStopped(message)
    }
  }

  private func beginActivity() {
    guard activityToken == nil else { return }
    activityToken = ProcessInfo.processInfo.beginActivity(
      options: [.userInitiated, .idleSystemSleepDisabled],
      reason: L10n.text("activity.lease_heartbeat")
    )
  }

  private func localizedHelperFailure(_ failure: HelperFailure?) -> String? {
    guard let failure else { return nil }
    switch failure.code {
    case .commandFailed:
      guard let exitStatus = failure.exitStatus else {
        return L10n.text("helper_error.pmset_execution_failed")
      }
      return L10n.format("helper_error.pmset_exit_status_format", exitStatus)
    case .commandTimedOut:
      return L10n.text("helper_error.pmset_timed_out")
    case .stateUnreadable:
      return L10n.text("helper_error.pmset_state_unreadable")
    case .stateMismatch:
      return L10n.text("helper_error.pmset_state_mismatch")
    case .executionFailed:
      return L10n.text("helper_error.pmset_execution_failed")
    }
  }

  private func endActivity() {
    guard let activityToken else { return }
    ProcessInfo.processInfo.endActivity(activityToken)
    self.activityToken = nil
  }

  static var helperIsInstalled: Bool {
    FileManager.default.isExecutableFile(atPath: AppConstants.helperInstallPath)
  }

  private static func isACConnected() -> Bool {
    guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
    else {
      return false
    }
    return sources.contains { source in
      guard
        let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
          as? [String: Any],
        let state = description[kIOPSPowerSourceStateKey] as? String
      else { return false }
      return state == kIOPSACPowerValue
    }
  }
}
