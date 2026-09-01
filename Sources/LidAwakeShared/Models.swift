import Foundation

public enum AppConstants {
  public static let bundleIdentifier = "com.takedashinpei.lidawake"
  public static let helperLabel = "com.takedashinpei.lidawake.helper"
  public static let helperInstallPath = "/Library/PrivilegedHelperTools/\(helperLabel)"
  public static let helperPlistInstallPath = "/Library/LaunchDaemons/\(helperLabel).plist"
  public static let leaseMaxAge: TimeInterval = 30
  public static let heartbeatInterval: TimeInterval = 10
  public static let helperPollInterval: TimeInterval = 3
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

public struct HelperStatus: Codable, Equatable, Sendable {
  public let schemaVersion: Int
  public let isBlockingSleep: Bool
  public let reason: BlockReason
  public let acConnected: Bool
  public let thermalLevel: ThermalLevel
  public let leaseFresh: Bool
  public let updatedAt: Date
  public let detail: String?

  public init(
    schemaVersion: Int = 1,
    isBlockingSleep: Bool,
    reason: BlockReason,
    acConnected: Bool,
    thermalLevel: ThermalLevel,
    leaseFresh: Bool,
    updatedAt: Date,
    detail: String? = nil
  ) {
    self.schemaVersion = schemaVersion
    self.isBlockingSleep = isBlockingSleep
    self.reason = reason
    self.acConnected = acConnected
    self.thermalLevel = thermalLevel
    self.leaseFresh = leaseFresh
    self.updatedAt = updatedAt
    self.detail = detail
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
