import Foundation
import Testing

@testable import LidAwakeShared

@Suite("LeasePolicy")
struct LeasePolicyTests {
  private let now = Date(timeIntervalSince1970: 1_000)

  @Test("Allows Keep Awake mode with a valid lease and safe conditions")
  func active() {
    #expect(LeasePolicy.evaluate(inputs()) == .active)
  }

  @Test("Rejects Keep Awake mode without external power")
  func battery() {
    #expect(LeasePolicy.evaluate(inputs(acConnected: false)) == .batteryPower)
  }

  @Test("Rejects a serious thermal state")
  func thermal() {
    #expect(LeasePolicy.evaluate(inputs(thermalLevel: .serious)) == .thermalPressure)
  }

  @Test("Rejects an expired lease")
  func expired() {
    let lease = LeaseRecord(
      enabled: true,
      ownerPID: 42,
      ownerExecutable: "LidAwakeApp",
      updatedAt: now.addingTimeInterval(-31)
    )
    #expect(LeasePolicy.evaluate(inputs(lease: lease)) == .leaseExpired)
  }

  @Test("Rejects a missing lease")
  func missing() {
    let input = LeaseInputs(
      lease: nil,
      now: now,
      acConnected: true,
      thermalLevel: .nominal,
      ownerIsRunning: true,
      ownerMatches: true
    )
    #expect(LeasePolicy.evaluate(input) == .leaseMissing)
  }

  @Test("Rejects an unknown lease schema")
  func invalidSchema() {
    let lease = LeaseRecord(
      schemaVersion: 2,
      enabled: true,
      ownerPID: 42,
      ownerExecutable: "LidAwakeApp",
      updatedAt: now
    )
    #expect(LeasePolicy.evaluate(inputs(lease: lease)) == .invalidLease)
  }

  @Test("Rejects a future-dated lease")
  func futureLease() {
    let lease = LeaseRecord(
      enabled: true,
      ownerPID: 42,
      ownerExecutable: "LidAwakeApp",
      updatedAt: now.addingTimeInterval(0.001)
    )
    #expect(LeasePolicy.evaluate(inputs(lease: lease)) == .leaseExpired)
  }

  @Test("Accepts the exact lease-expiry boundary")
  func expiryBoundary() {
    let lease = LeaseRecord(
      enabled: true,
      ownerPID: 42,
      ownerExecutable: "LidAwakeApp",
      updatedAt: now.addingTimeInterval(-AppConstants.leaseMaxAge)
    )
    #expect(LeasePolicy.evaluate(inputs(lease: lease)) == .active)
  }

  @Test("Rejects a critical thermal state")
  func criticalThermal() {
    #expect(LeasePolicy.evaluate(inputs(thermalLevel: .critical)) == .thermalPressure)
  }

  @Test("Treats fair and unknown as noncritical macOS thermal states")
  func nonCriticalThermalLevels() {
    #expect(LeasePolicy.evaluate(inputs(thermalLevel: .fair)) == .active)
    #expect(LeasePolicy.evaluate(inputs(thermalLevel: .unknown)) == .active)
  }

  @Test("Evaluates lease validity before power and thermal conditions")
  func failurePrecedence() {
    let lease = LeaseRecord(
      enabled: false,
      ownerPID: 42,
      ownerExecutable: "LidAwakeApp",
      updatedAt: now
    )
    #expect(
      LeasePolicy.evaluate(
        inputs(lease: lease, acConnected: false, thermalLevel: .critical)
      ) == .leaseDisabled
    )
  }

  @Test("Rejects a lease whose owner process has exited")
  func deadOwner() {
    #expect(LeasePolicy.evaluate(inputs(ownerIsRunning: false)) == .ownerNotRunning)
  }

  @Test("Rejects a lease whose owner executable does not match")
  func mismatchedOwner() {
    #expect(LeasePolicy.evaluate(inputs(ownerMatches: false)) == .ownerMismatch)
  }

  @Test("Rejects a disabled lease")
  func disabled() {
    let lease = LeaseRecord(
      enabled: false,
      ownerPID: 42,
      ownerExecutable: "LidAwakeApp",
      updatedAt: now
    )
    #expect(LeasePolicy.evaluate(inputs(lease: lease)) == .leaseDisabled)
  }

  private func inputs(
    lease: LeaseRecord? = nil,
    acConnected: Bool = true,
    thermalLevel: ThermalLevel = .nominal,
    ownerIsRunning: Bool = true,
    ownerMatches: Bool = true
  ) -> LeaseInputs {
    LeaseInputs(
      lease: lease
        ?? LeaseRecord(
          enabled: true,
          ownerPID: 42,
          ownerExecutable: "LidAwakeApp",
          updatedAt: now
        ),
      now: now,
      acConnected: acConnected,
      thermalLevel: thermalLevel,
      ownerIsRunning: ownerIsRunning,
      ownerMatches: ownerMatches
    )
  }
}

@Suite("PowerSettingParser")
struct PowerSettingParserTests {
  @Test("Parses an enabled SleepDisabled value from pmset -g")
  func enabled() {
    let output = """
      System-wide power settings:
       SleepDisabled\t\t1
      Currently in use:
       sleep                1
      """
    #expect(PowerSettingParser.sleepDisabled(fromPMSetOutput: output) == true)
  }

  @Test("Parses a disabled SleepDisabled value from pmset -g")
  func disabled() {
    #expect(PowerSettingParser.sleepDisabled(fromPMSetOutput: " SleepDisabled 0\n") == false)
  }

  @Test("Returns unknown when SleepDisabled is absent")
  func missing() {
    #expect(PowerSettingParser.sleepDisabled(fromPMSetOutput: " sleep 1\n") == nil)
  }

  @Test("Returns unknown for a value other than zero or one")
  func invalidValue() {
    #expect(PowerSettingParser.sleepDisabled(fromPMSetOutput: "SleepDisabled 2\n") == nil)
  }

  @Test("Does not confuse a similarly named setting")
  func similarName() {
    #expect(PowerSettingParser.sleepDisabled(fromPMSetOutput: "TCPKeepAliveDuringSleep 1\n") == nil)
  }
}

@Suite("LeaseFreshness")
struct LeaseFreshnessTests {
  private let now = Date(timeIntervalSince1970: 1_000)

  @Test("Treats current time and the expiry boundary as fresh")
  func boundaries() {
    #expect(LeaseFreshness.isFresh(updatedAt: now, now: now))
    #expect(
      LeaseFreshness.isFresh(
        updatedAt: now.addingTimeInterval(-AppConstants.leaseMaxAge),
        now: now
      )
    )
  }

  @Test("Rejects an expired or future timestamp as not fresh")
  func rejectedTimes() {
    #expect(
      !LeaseFreshness.isFresh(
        updatedAt: now.addingTimeInterval(-AppConstants.leaseMaxAge - 0.001),
        now: now
      )
    )
    #expect(!LeaseFreshness.isFresh(updatedAt: now.addingTimeInterval(0.001), now: now))
  }
}

@Suite("SleepTransitionTracker")
struct SleepTransitionTrackerTests {
  @Test("Requires a transition from unknown even toward the safe state")
  func unknownRequiresTransition() {
    let tracker = SleepTransitionTracker()
    #expect(tracker.requiresTransition(to: false))
    #expect(tracker.requiresTransition(to: true))
  }

  @Test("Skips a duplicate transition to a verified state")
  func successIsRemembered() {
    var tracker = SleepTransitionTracker()
    tracker.record(desiredState: true, succeeded: true)
    #expect(tracker.appliedState == true)
    #expect(!tracker.requiresTransition(to: true))
    #expect(tracker.requiresTransition(to: false))
  }

  @Test("Retries a safe transition after failure")
  func failureForgetsPriorState() {
    var tracker = SleepTransitionTracker(appliedState: true)
    tracker.record(desiredState: false, succeeded: false)
    #expect(tracker.appliedState == nil)
    #expect(tracker.requiresTransition(to: false))
  }
}
