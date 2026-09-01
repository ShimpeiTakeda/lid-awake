import Foundation
import LidAwakeShared

enum PrivilegedInstaller {
  enum InstallerError: LocalizedError {
    case resourceMissing(String)
    case authorizationFailed(String)

    var errorDescription: String? {
      switch self {
      case .resourceMissing(let name): "必要なファイルが見つかりません: \(name)"
      case .authorizationFailed(let message): "管理者認証に失敗しました: \(message)"
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

    let command = [
      "/bin/launchctl bootout system/\(AppConstants.helperLabel) >/dev/null 2>&1 || true",
      "/usr/bin/pmset -a disablesleep 0",
      "/usr/bin/install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools",
      "/usr/bin/install -o root -g wheel -m 755 \(shellQuote(helper.path)) \(shellQuote(AppConstants.helperInstallPath))",
      "/usr/bin/install -o root -g wheel -m 644 \(shellQuote(plist.path)) \(shellQuote(AppConstants.helperPlistInstallPath))",
      "/bin/launchctl bootstrap system \(shellQuote(AppConstants.helperPlistInstallPath))",
      "/bin/launchctl enable system/\(AppConstants.helperLabel)",
      "/bin/launchctl kickstart -k system/\(AppConstants.helperLabel)",
    ].joined(separator: " && ")
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

  private static func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}
