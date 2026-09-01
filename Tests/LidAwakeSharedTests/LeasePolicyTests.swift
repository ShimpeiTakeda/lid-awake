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
