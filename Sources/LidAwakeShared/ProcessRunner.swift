import Darwin
import Foundation

public struct ProcessResult: Equatable, Sendable {
  public let terminationStatus: Int32
  public let standardOutput: String
  public let standardError: String

  public init(terminationStatus: Int32, standardOutput: String, standardError: String) {
    self.terminationStatus = terminationStatus
    self.standardOutput = standardOutput
    self.standardError = standardError
  }
}

public enum ProcessRunnerError: LocalizedError, Equatable {
  case invalidTimeout
  case timedOut(executable: String, seconds: TimeInterval)

  public var errorDescription: String? {
    switch self {
    case .invalidTimeout:
      "process timeoutは0秒より大きい値が必要です"
    case .timedOut(let executable, let seconds):
      "\(executable)が\(seconds)秒以内に終了しませんでした"
    }
  }
}

public enum SynchronousProcessRunner {
  public static func run(
    executable: String,
    arguments: [String],
    timeout: TimeInterval
  ) throws -> ProcessResult {
    guard timeout > 0 else { throw ProcessRunnerError.invalidTimeout }

    let manager = FileManager.default
    let captureDirectory = manager.temporaryDirectory
      .appendingPathComponent("lid-awake-process-\(UUID().uuidString)", isDirectory: true)
    try manager.createDirectory(at: captureDirectory, withIntermediateDirectories: false)
    try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: captureDirectory.path)
    defer { try? manager.removeItem(at: captureDirectory) }

    let stdoutURL = captureDirectory.appendingPathComponent("stdout")
    let stderrURL = captureDirectory.appendingPathComponent("stderr")
    guard manager.createFile(atPath: stdoutURL.path, contents: nil),
      manager.createFile(atPath: stderrURL.path, contents: nil)
    else {
      throw CocoaError(.fileWriteUnknown)
    }
    try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stdoutURL.path)
    try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stderrURL.path)
    let stdout = try FileHandle(forWritingTo: stdoutURL)
    let stderr = try FileHandle(forWritingTo: stderrURL)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()

    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.01)
    }

    if process.isRunning {
      process.terminate()
      let terminationDeadline = Date().addingTimeInterval(0.5)
      while process.isRunning, Date() < terminationDeadline {
        Thread.sleep(forTimeInterval: 0.01)
      }
      if process.isRunning {
        kill(process.processIdentifier, SIGKILL)
      }
      process.waitUntilExit()
      throw ProcessRunnerError.timedOut(executable: executable, seconds: timeout)
    }

    process.waitUntilExit()
    try stdout.close()
    try stderr.close()
    return ProcessResult(
      terminationStatus: process.terminationStatus,
      standardOutput: String(decoding: try Data(contentsOf: stdoutURL), as: UTF8.self),
      standardError: String(decoding: try Data(contentsOf: stderrURL), as: UTF8.self)
    )
  }
}
