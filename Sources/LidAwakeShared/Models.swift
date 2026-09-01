import Foundation

public enum AppConstants {
  public static let bundleIdentifier = "com.takedashinpei.lidawake"
  public static let helperLabel = "com.takedashinpei.lidawake.helper"
  public static let helperInstallPath = "/Library/PrivilegedHelperTools/\(helperLabel)"
  public static let helperPlistInstallPath = "/Library/LaunchDaemons/\(helperLabel).plist"
  public static let leaseMaxAge: TimeInterval = 30
  public static let heartbeatInterval: TimeInterval = 10
  public static let helperPollInterval: TimeInterval = 3
  public static let commandTimeout: TimeInterval = 5
  public static let helperStatusSchemaVersion = 4
}

public struct LeaseRecord: Codable, Equatable, Sendable {
  public let schemaVersion: Int
  public let enabled: Bool
  public let ownerPID: Int32
  public let ownerExecutable: String
  public let updatedAt: Date

  public init(
    schemaVersion: Int = 1,
    enabled: Bool,
    ownerPID: Int32,
    ownerExecutable: String,
    updatedAt: Date
  ) {
    self.schemaVersion = schemaVersion
    self.enabled = enabled
    self.ownerPID = ownerPID
    self.ownerExecutable = ownerExecutable
    self.updatedAt = updatedAt
  }
}

public enum ThermalLevel: String, Codable, Sendable {
  case nominal
  case fair
  case serious
  case critical
  case unknown

  public var isUnsafe: Bool {
    self == .serious || self == .critical
  }
}

public enum BlockReason: String, Codable, Sendable {
  case active
  case leaseMissing
  case leaseDisabled
  case leaseExpired
  case ownerNotRunning
  case ownerMismatch
  case batteryPower
  case thermalPressure
  case invalidLease
  case helperError
}

public struct HelperFailure: Codable, Equatable, Sendable {
  public enum Code: String, Codable, Sendable {
    case commandFailed
    case commandTimedOut
    case stateUnreadable
    case stateMismatch
    case executionFailed
  }

  public let code: Code
  public let exitStatus: Int32?

  public init(code: Code, exitStatus: Int32? = nil) {
    self.code = code
    self.exitStatus = exitStatus
  }
}

public struct HelperStatus: Codable, Equatable, Sendable {
  public let schemaVersion: Int
  public let isBlockingSleep: Bool
  public let reason: BlockReason
  public let acConnected: Bool
  public let thermalLevel: ThermalLevel
  public let leaseFresh: Bool
  public let updatedAt: Date
  public let failure: HelperFailure?
  public let detail: String?

  public init(
    schemaVersion: Int = AppConstants.helperStatusSchemaVersion,
    isBlockingSleep: Bool,
    reason: BlockReason,
    acConnected: Bool,
    thermalLevel: ThermalLevel,
    leaseFresh: Bool,
    updatedAt: Date,
    failure: HelperFailure? = nil,
    detail: String? = nil
  ) {
    self.schemaVersion = schemaVersion
    self.isBlockingSleep = isBlockingSleep
    self.reason = reason
    self.acConnected = acConnected
    self.thermalLevel = thermalLevel
    self.leaseFresh = leaseFresh
    self.updatedAt = updatedAt
    self.failure = failure
    self.detail = detail
  }
}

public enum PowerSettingParser {
  public static func sleepDisabled(fromPMSetOutput output: String) -> Bool? {
    for line in output.split(separator: "\n") {
      let fields = line.split(whereSeparator: { $0.isWhitespace })
      guard fields.first == "SleepDisabled", let value = fields.last else { continue }
      if value == "1" { return true }
      if value == "0" { return false }
    }
    return nil
  }
}

public struct LeaseInputs: Sendable {
  public let lease: LeaseRecord?
  public let now: Date
  public let acConnected: Bool
  public let thermalLevel: ThermalLevel
  public let ownerIsRunning: Bool
  public let ownerMatches: Bool

  public init(
    lease: LeaseRecord?,
    now: Date,
    acConnected: Bool,
    thermalLevel: ThermalLevel,
    ownerIsRunning: Bool,
    ownerMatches: Bool
  ) {
    self.lease = lease
    self.now = now
    self.acConnected = acConnected
    self.thermalLevel = thermalLevel
    self.ownerIsRunning = ownerIsRunning
    self.ownerMatches = ownerMatches
  }
}

public enum LeasePolicy {
  public static func evaluate(_ input: LeaseInputs) -> BlockReason {
    guard let lease = input.lease else { return .leaseMissing }
    guard lease.schemaVersion == 1 else { return .invalidLease }
    guard lease.enabled else { return .leaseDisabled }
    guard input.now.timeIntervalSince(lease.updatedAt) >= 0,
      input.now.timeIntervalSince(lease.updatedAt) <= AppConstants.leaseMaxAge
    else {
      return .leaseExpired
    }
    guard input.ownerIsRunning else { return .ownerNotRunning }
    guard input.ownerMatches else { return .ownerMismatch }
    guard input.acConnected else { return .batteryPower }
    guard !input.thermalLevel.isUnsafe else { return .thermalPressure }
    return .active
  }
}

public enum LeaseFreshness {
  public static func isFresh(updatedAt: Date, now: Date) -> Bool {
    let age = now.timeIntervalSince(updatedAt)
    return age >= 0 && age <= AppConstants.leaseMaxAge
  }
}

/// Tracks the last `SleepDisabled` state verified by the helper.
/// A failed apply or verification returns the state to unknown so a safe retry is never skipped.
public struct SleepTransitionTracker: Equatable, Sendable {
  public private(set) var appliedState: Bool?

  public init(appliedState: Bool? = nil) {
    self.appliedState = appliedState
  }

  public func requiresTransition(to desiredState: Bool) -> Bool {
    appliedState != desiredState
  }

  public mutating func record(desiredState: Bool, succeeded: Bool) {
    appliedState = succeeded ? desiredState : nil
  }
}
