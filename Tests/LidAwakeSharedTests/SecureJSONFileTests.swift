import Darwin
import Foundation
import Testing

@testable import LidAwakeShared

@Suite("SecureJSONFile")
struct SecureJSONFileTests {
  @Test("Creates a 0700 directory and 0600 file and round-trips JSON")
  func permissionsAndRoundTrip() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("nested/lease.json")
    let lease = LeaseRecord(
      enabled: true,
      ownerPID: 42,
      ownerExecutable: "LidAwakeApp",
      updatedAt: Date(timeIntervalSince1970: 1_000)
    )

    try SecureJSONFile.write(lease, to: file)

    #expect(try permissions(of: file.deletingLastPathComponent()) == 0o700)
    #expect(try permissions(of: file) == 0o600)
    #expect(try SecureJSONFile.read(LeaseRecord.self, from: file) == lease)
  }

  @Test("Atomically replaces an existing file without leaving a temporary file")
  func replacement() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("status.json")
    let first = status(reason: .active)
    let second = status(reason: .batteryPower)

    try SecureJSONFile.write(first, to: file)
    try SecureJSONFile.write(second, to: file)

    #expect(try SecureJSONFile.read(HelperStatus.self, from: file) == second)
    let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
    #expect(names == ["status.json"])
  }

  @Test("Rejects malformed JSON")
  func malformedJSON() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("lease.json")
    try Data("not-json".utf8).write(to: file)

    #expect(throws: (any Error).self) {
      try SecureJSONFile.read(LeaseRecord.self, from: file)
    }
  }

  @Test("Round-trips a structured helper failure without relying on display text")
  func helperFailureRoundTrip() throws {
    let root = try temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("status.json")
    let failure = HelperFailure(code: .commandFailed, exitStatus: 7)
    let value = HelperStatus(
      isBlockingSleep: false,
      reason: .helperError,
      acConnected: true,
      thermalLevel: .nominal,
      leaseFresh: true,
      updatedAt: Date(timeIntervalSince1970: 1_000),
      failure: failure,
      detail: "pmset returned exit status 7"
    )

    try SecureJSONFile.write(value, to: file)

    let decoded = try SecureJSONFile.read(HelperStatus.self, from: file)
    #expect(decoded.failure == failure)
    #expect(decoded == value)
  }

  private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("lid-awake-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    return url
  }

  private func permissions(of url: URL) throws -> mode_t {
    var metadata = stat()
    guard lstat(url.path, &metadata) == 0 else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    return metadata.st_mode & 0o777
  }

  private func status(reason: BlockReason) -> HelperStatus {
    HelperStatus(
      isBlockingSleep: reason == .active,
      reason: reason,
      acConnected: true,
      thermalLevel: .nominal,
      leaseFresh: true,
      updatedAt: Date(timeIntervalSince1970: 1_000)
    )
  }
}
