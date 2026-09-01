import CryptoKit
import Foundation
import LidAwakeShared

enum PrivilegedInstaller {
  enum InstallerError: LocalizedError {
    case resourceMissing(String)
    case authorizationFailed(String)

    var errorDescription: String? {
      switch self {
      case .resourceMissing(let name): L10n.format("installer.resource_missing_format", name)
      case .authorizationFailed(let message):
        L10n.format("installer.authorization_failed_format", message)
      }
    }
  }

  static func install() throws {
    let helper = Bundle.main.bundleURL
      .appendingPathComponent("Contents/Library/LaunchServices/\(AppConstants.helperLabel)")
    guard FileManager.default.isExecutableFile(atPath: helper.path) else {
      throw InstallerError.resourceMissing(helper.lastPathComponent)
    }
    guard let plist = Bundle.main.url(forResource: AppConstants.helperLabel, withExtension: "plist")
    else {
      throw InstallerError.resourceMissing("\(AppConstants.helperLabel).plist")
    }

    let command = try PrivilegedInstallCommand(
      helperSourcePath: helper.path,
      plistSourcePath: plist.path,
      helperSHA256: try sha256(of: helper),
      plistSHA256: try sha256(of: plist)
    ).render()
    try runAsAdministrator(command)
  }

  private static func runAsAdministrator(_ command: String) throws {
    let escaped =
      command
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
    let script = "do shell script \"\(escaped)\" with administrator privileges"
    let process = Process()
    let stderr = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-e", script]
    process.standardError = stderr
    process.standardOutput = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      let data = stderr.fileHandleForReading.readDataToEndOfFile()
      let message = String(decoding: data, as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
      throw InstallerError.authorizationFailed(message)
    }
  }

  private static func sha256(of url: URL) throws -> String {
    let digest = SHA256.hash(data: try Data(contentsOf: url))
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}
