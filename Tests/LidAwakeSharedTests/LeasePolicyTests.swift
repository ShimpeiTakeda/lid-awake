import Foundation
import Testing

@testable import LidAwakeShared

@Suite("LeasePolicy")
struct LeasePolicyTests {
  private let now = Date(timeIntervalSince1970: 1_000)

  @Test("有効なleaseと安全条件で常時起動を許可する")
  func active() {
    #expect(LeasePolicy.evaluate(inputs()) == .active)
  }

  @Test("ACが外れたら常時起動を拒否する")
  func battery() {
    #expect(LeasePolicy.evaluate(inputs(acConnected: false)) == .batteryPower)
  }

  @Test("重大な熱状態では常時起動を拒否する")
  func thermal() {
    #expect(LeasePolicy.evaluate(inputs(thermalLevel: .serious)) == .thermalPressure)
  }

  @Test("期限切れleaseを拒否する")
  func expired() {
    let lease = LeaseRecord(
      enabled: true,
      ownerPID: 42,
      ownerExecutable: "LidAwakeApp",
      updatedAt: now.addingTimeInterval(-31)
    )
    #expect(LeasePolicy.evaluate(inputs(lease: lease)) == .leaseExpired)
  }

  @Test("leaseがなければ拒否する")
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

  @Test("未知のschemaを拒否する")
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

  @Test("未来時刻のleaseを拒否する")
  func futureLease() {
    let lease = LeaseRecord(
      enabled: true,
      ownerPID: 42,
      ownerExecutable: "LidAwakeApp",
      updatedAt: now.addingTimeInterval(0.001)
    )
    #expect(LeasePolicy.evaluate(inputs(lease: lease)) == .leaseExpired)
  }

  @Test("lease期限の境界値は有効")
  func expiryBoundary() {
    let lease = LeaseRecord(
      enabled: true,
      ownerPID: 42,
      ownerExecutable: "LidAwakeApp",
      updatedAt: now.addingTimeInterval(-AppConstants.leaseMaxAge)
    )
    #expect(LeasePolicy.evaluate(inputs(lease: lease)) == .active)
  }

  @Test("criticalの熱状態では常時起動を拒否する")
  func criticalThermal() {
    #expect(LeasePolicy.evaluate(inputs(thermalLevel: .critical)) == .thermalPressure)
  }

  @Test("fairとunknownはmacOSの危険判定ではない")
  func nonCriticalThermalLevels() {
    #expect(LeasePolicy.evaluate(inputs(thermalLevel: .fair)) == .active)
    #expect(LeasePolicy.evaluate(inputs(thermalLevel: .unknown)) == .active)
  }

  @Test("複数異常ではleaseの検証を電源・熱より先に行う")
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

  @Test("owner processが終了したleaseを拒否する")
  func deadOwner() {
    #expect(LeasePolicy.evaluate(inputs(ownerIsRunning: false)) == .ownerNotRunning)
  }

  @Test("owner executableが一致しないleaseを拒否する")
  func mismatchedOwner() {
    #expect(LeasePolicy.evaluate(inputs(ownerMatches: false)) == .ownerMismatch)
  }

  @Test("無効化されたleaseを拒否する")
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
  @Test("pmset -gのSleepDisabled有効値を読む")
  func enabled() {
    let output = """
      System-wide power settings:
       SleepDisabled\t\t1
      Currently in use:
       sleep                1
      """
    #expect(PowerSettingParser.sleepDisabled(fromPMSetOutput: output) == true)
  }

  @Test("pmset -gのSleepDisabled無効値を読む")
  func disabled() {
    #expect(PowerSettingParser.sleepDisabled(fromPMSetOutput: " SleepDisabled 0\n") == false)
  }

  @Test("SleepDisabledがなければ不明として扱う")
  func missing() {
    #expect(PowerSettingParser.sleepDisabled(fromPMSetOutput: " sleep 1\n") == nil)
  }

  @Test("値が0または1以外なら不明として扱う")
  func invalidValue() {
    #expect(PowerSettingParser.sleepDisabled(fromPMSetOutput: "SleepDisabled 2\n") == nil)
  }

  @Test("似た名前の設定を誤認しない")
  func similarName() {
    #expect(PowerSettingParser.sleepDisabled(fromPMSetOutput: "TCPKeepAliveDuringSleep 1\n") == nil)
  }
}

@Suite("LeaseFreshness")
struct LeaseFreshnessTests {
  private let now = Date(timeIntervalSince1970: 1_000)

  @Test("現在時刻と期限境界はfresh")
  func boundaries() {
    #expect(LeaseFreshness.isFresh(updatedAt: now, now: now))
    #expect(
      LeaseFreshness.isFresh(
        updatedAt: now.addingTimeInterval(-AppConstants.leaseMaxAge),
        now: now
      )
    )
  }

  @Test("期限超過と未来時刻はfreshではない")
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
  @Test("初期状態では安全側を含む実状態確認を省略しない")
  func unknownRequiresTransition() {
    let tracker = SleepTransitionTracker()
    #expect(tracker.requiresTransition(to: false))
    #expect(tracker.requiresTransition(to: true))
  }

  @Test("成功した状態への重複遷移を省略する")
  func successIsRemembered() {
    var tracker = SleepTransitionTracker()
    tracker.record(desiredState: true, succeeded: true)
    #expect(tracker.appliedState == true)
    #expect(!tracker.requiresTransition(to: true))
    #expect(tracker.requiresTransition(to: false))
  }

  @Test("失敗後は安全側遷移を必ず再試行する")
  func failureForgetsPriorState() {
    var tracker = SleepTransitionTracker(appliedState: true)
    tracker.record(desiredState: false, succeeded: false)
    #expect(tracker.appliedState == nil)
    #expect(tracker.requiresTransition(to: false))
  }
}
