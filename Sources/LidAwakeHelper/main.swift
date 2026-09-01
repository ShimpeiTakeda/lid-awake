import Darwin
import Foundation
import IOKit.ps
import LidAwakeShared

private struct ConsoleUser {
  let uid: uid_t
  let gid: gid_t
  let homeDirectory: String
}

private final class HelperRuntime: @unchecked Sendable {
  private let queue = DispatchQueue(label: "com.takedashinpei.lidawake.helper.runtime")
  private var timer: DispatchSourceTimer?
  private var transitionTracker = SleepTransitionTracker()
  private var transitionFailure: HelperFailure?
  private var transitionFailureDetail: String?
  private var isStopping = false

  func start() {
    queue.async {
      _ = self.transition(to: false)
      self.installSignalHandlers()
      let timer = DispatchSource.makeTimerSource(queue: self.queue)
      timer.schedule(deadline: .now(), repeating: AppConstants.helperPollInterval)
      timer.setEventHandler { [weak self] in self?.tick() }
      self.timer = timer
      timer.resume()
    }
    dispatchMain()
  }

  private func installSignalHandlers() {
    signal(SIGTERM, SIG_IGN)
    signal(SIGINT, SIG_IGN)
    for signalNumber in [SIGTERM, SIGINT] {
      let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: queue)
      source.setEventHandler { [weak self] in self?.shutdown() }
      source.resume()
      SignalStore.shared.sources.append(source)
    }
  }

  private func shutdown() {
    guard !isStopping else { return }
    isStopping = true
    timer?.cancel()
    _ = applySleepBlock(false)
    exit(EXIT_SUCCESS)
  }

  private func tick() {
    guard !isStopping else { return }
    guard let user = currentConsoleUser() else {
      transition(to: false)
      return
    }

    let leaseURL = LidAwakePaths.leaseFile(homeDirectory: user.homeDirectory)
    let lease = validatedLease(at: leaseURL, expectedOwner: user.uid)
    let ownerStatus = ownerValidation(for: lease)
    let acConnected = Self.isACConnected()
    let thermalLevel = Self.currentThermalLevel()
    let now = Date()
    let reason = LeasePolicy.evaluate(
      LeaseInputs(
        lease: lease,
        now: now,
        acConnected: acConnected,
        thermalLevel: thermalLevel,
        ownerIsRunning: ownerStatus.isRunning,
        ownerMatches: ownerStatus.matches
      ))
    let shouldBlock = reason == .active
    let transitionSucceeded = transition(to: shouldBlock)
    let finalReason: BlockReason = transitionSucceeded ? reason : .helperError
    let fresh = lease.map { LeaseFreshness.isFresh(updatedAt: $0.updatedAt, now: now) } ?? false
    let status = HelperStatus(
      isBlockingSleep: transitionSucceeded
        ? shouldBlock : (transitionTracker.appliedState ?? false),
      reason: finalReason,
      acConnected: acConnected,
      thermalLevel: thermalLevel,
      leaseFresh: fresh,
      updatedAt: now,
      failure: transitionSucceeded ? nil : transitionFailure,
      detail: transitionSucceeded ? nil : transitionFailureDetail
    )
    writeStatus(status, for: user)
  }

  private func validatedLease(at url: URL, expectedOwner: uid_t) -> LeaseRecord? {
    var metadata = stat()
    guard lstat(url.path, &metadata) == 0,
      (metadata.st_mode & S_IFMT) == S_IFREG,
      metadata.st_uid == expectedOwner,
      (metadata.st_mode & 0o077) == 0
    else {
      return nil
    }
    return try? SecureJSONFile.read(LeaseRecord.self, from: url)
  }

  private func ownerValidation(for lease: LeaseRecord?) -> (isRunning: Bool, matches: Bool) {
    guard let lease, lease.ownerPID > 1, lease.ownerExecutable == "LidAwakeApp" else {
      return (false, false)
    }
    let running = kill(lease.ownerPID, 0) == 0 || errno == EPERM
    guard running else { return (false, false) }
    // PROC_PIDPATHINFO_MAXSIZE is a C macro Swift cannot import on current SDKs.
    // Four PATH_MAX buffers matches libproc's documented maximum.
    var buffer = [CChar](repeating: 0, count: Int(PATH_MAX) * 4)
    let count = proc_pidpath(lease.ownerPID, &buffer, UInt32(buffer.count))
    guard count > 0 else { return (true, false) }
    let path = String(
      decoding: buffer.prefix(Int(count)).map { UInt8(bitPattern: $0) },
      as: UTF8.self
    )
    return (true, path.hasSuffix("/LidAwakeApp"))
  }

  @discardableResult
  private func transition(to shouldBlock: Bool) -> Bool {
    guard transitionTracker.requiresTransition(to: shouldBlock) else { return true }
    let result = applySleepBlock(shouldBlock)
    transitionFailure = result.failure
    transitionFailureDetail = result.detail
    transitionTracker.record(desiredState: shouldBlock, succeeded: result.succeeded)
    return result.succeeded
  }

  private func applySleepBlock(_ enabled: Bool) -> (
    succeeded: Bool,
    failure: HelperFailure?,
    detail: String?
  ) {
    do {
      let result = try SynchronousProcessRunner.run(
        executable: "/usr/bin/pmset",
        arguments: ["-a", "disablesleep", enabled ? "1" : "0"],
        timeout: AppConstants.commandTimeout
      )
      let errorText = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
      guard result.terminationStatus == 0 else {
        let detail =
          errorText.isEmpty
          ? "pmset returned exit status \(result.terminationStatus)"
          : "pmset: \(errorText)"
        return (
          false,
          HelperFailure(code: .commandFailed, exitStatus: result.terminationStatus),
          detail
        )
      }
      guard let observed = readSleepBlockState() else {
        return (
          false,
          HelperFailure(code: .stateUnreadable),
          "Could not read SleepDisabled after applying the pmset change"
        )
      }
      guard observed == enabled else {
        return (
          false,
          HelperFailure(code: .stateMismatch),
          "SleepDisabled did not match the requested state after pmset completed"
        )
      }
      return (true, nil, nil)
    } catch ProcessRunnerError.timedOut {
      return (
        false,
        HelperFailure(code: .commandTimedOut),
        "pmset did not exit within \(AppConstants.commandTimeout) seconds"
      )
    } catch {
      return (
        false,
        HelperFailure(code: .executionFailed),
        "Could not run pmset: \(error.localizedDescription)"
      )
    }
  }

  private func readSleepBlockState() -> Bool? {
    do {
      let result = try SynchronousProcessRunner.run(
        executable: "/usr/bin/pmset",
        arguments: ["-g"],
        timeout: AppConstants.commandTimeout
      )
      guard result.terminationStatus == 0 else { return nil }
      return PowerSettingParser.sleepDisabled(fromPMSetOutput: result.standardOutput)
    } catch {
      return nil
    }
  }

  private func writeStatus(_ status: HelperStatus, for user: ConsoleUser) {
    let url = LidAwakePaths.statusFile(homeDirectory: user.homeDirectory)
    try? SecureJSONFile.write(status, to: url, owner: (user.uid, user.gid))
  }

  private func currentConsoleUser() -> ConsoleUser? {
    var metadata = stat()
    guard stat("/dev/console", &metadata) == 0, metadata.st_uid > 0,
      let record = getpwuid(metadata.st_uid),
      let home = record.pointee.pw_dir
    else {
      return nil
    }
    return ConsoleUser(
      uid: metadata.st_uid,
      gid: metadata.st_gid,
      homeDirectory: String(cString: home)
    )
  }

  private static func isACConnected() -> Bool {
    guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
      let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
    else {
      return false
    }
    for source in sources {
      guard
        let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue()
          as? [String: Any],
        let state = description[kIOPSPowerSourceStateKey] as? String
      else { continue }
      if state == kIOPSACPowerValue { return true }
    }
    return false
  }

  private static func currentThermalLevel() -> ThermalLevel {
    switch ProcessInfo.processInfo.thermalState {
    case .nominal: .nominal
    case .fair: .fair
    case .serious: .serious
    case .critical: .critical
    @unknown default: .unknown
    }
  }
}

private final class SignalStore: @unchecked Sendable {
  static let shared = SignalStore()
  var sources: [DispatchSourceSignal] = []
}

HelperRuntime().start()
