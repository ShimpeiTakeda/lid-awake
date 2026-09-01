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
        mode = .error("初期設定に失敗しました: \(error.localizedDescription)")
        return
      }
    }

    guard Self.isACConnected() else {
      mode = .safetyStopped("電源アダプタを接続してください")
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

    var helperFailureDetail: String?
    for _ in 0..<24 {
      refreshStatus()
      if helperStatus?.isBlockingSleep == true {
        mode = .active
        return
      }
      if helperStatus?.reason == .helperError {
        helperFailureDetail = helperStatus?.detail
      }
      try? await Task.sleep(for: .milliseconds(500))
    }
    await stop()
    mode = .error(
      helperFailureDetail.map { "常時起動を有効にできませんでした: \($0)" }
        ?? "常時起動を有効にできませんでした"
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
    mode = .error("通常モードへの復帰確認に失敗しました")
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
      mode = .error("状態ファイルを保存できません: \(error.localizedDescription)")
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
        mode = .error("安全監視helperから応答がありません")
      }
      return
    }
    helperStatus = status
    if status.schemaVersion != AppConstants.helperStatusSchemaVersion {
      switch mode {
      case .active, .starting:
        mode = .error("安全監視helperの更新が必要です")
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
        case .batteryPower: "電源が外れたため安全停止しました"
        case .thermalPressure: "Macの熱状態が高いため安全停止しました"
        default: "安全条件を満たさなくなったため停止しました"
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
      reason: "Lid Awakeの安全leaseを更新するため"
    )
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
