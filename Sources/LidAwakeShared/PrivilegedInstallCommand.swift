import Foundation

public enum POSIXShell {
  public static func quote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}

public struct PrivilegedInstallCommand: Equatable, Sendable {
  public let helperSourcePath: String
  public let plistSourcePath: String
  public let helperSHA256: String
  public let plistSHA256: String

  public init(
    helperSourcePath: String,
    plistSourcePath: String,
    helperSHA256: String,
    plistSHA256: String
  ) {
    self.helperSourcePath = helperSourcePath
    self.plistSourcePath = plistSourcePath
    self.helperSHA256 = helperSHA256
    self.plistSHA256 = plistSHA256
  }

  public func render() throws -> String {
    guard Self.isSHA256(helperSHA256), Self.isSHA256(plistSHA256) else {
      throw ValidationError.invalidSHA256
    }

    let helperSource = POSIXShell.quote(helperSourcePath)
    let plistSource = POSIXShell.quote(plistSourcePath)
    let helperTarget = POSIXShell.quote(AppConstants.helperInstallPath)
    let plistTarget = POSIXShell.quote(AppConstants.helperPlistInstallPath)
    let label = POSIXShell.quote("system/\(AppConstants.helperLabel)")

    return [
      "set -eu",
      "stage_dir=$(/usr/bin/mktemp -d /var/tmp/lid-awake-install.XXXXXX)",
      "cleanup() { /bin/rm -f \"$stage_dir/helper\" \"$stage_dir/helper.plist\"; /bin/rmdir \"$stage_dir\"; }",
      "trap cleanup EXIT HUP INT TERM",
      "/usr/bin/install -o root -g wheel -m 755 \(helperSource) \"$stage_dir/helper\"",
      "/usr/bin/install -o root -g wheel -m 644 \(plistSource) \"$stage_dir/helper.plist\"",
      "helper_digest=$(/usr/bin/shasum -a 256 \"$stage_dir/helper\" | /usr/bin/awk '{print $1}')",
      "plist_digest=$(/usr/bin/shasum -a 256 \"$stage_dir/helper.plist\" | /usr/bin/awk '{print $1}')",
      "/usr/bin/test \"$helper_digest\" = \(POSIXShell.quote(helperSHA256))",
      "/usr/bin/test \"$plist_digest\" = \(POSIXShell.quote(plistSHA256))",
      "/bin/launchctl bootout \(label) >/dev/null 2>&1 || true",
      "/usr/bin/pmset -a disablesleep 0",
      "/usr/bin/install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools",
      "/usr/bin/install -o root -g wheel -m 755 \"$stage_dir/helper\" \(helperTarget)",
      "/usr/bin/install -o root -g wheel -m 644 \"$stage_dir/helper.plist\" \(plistTarget)",
      "/bin/launchctl bootstrap system \(plistTarget)",
      "/bin/launchctl enable \(label)",
      "/bin/launchctl kickstart -k \(label)",
    ].joined(separator: " && ")
  }

  public enum ValidationError: LocalizedError, Equatable {
    case invalidSHA256

    public var errorDescription: String? {
      "The install artifact SHA-256 is invalid"
    }
  }

  private static func isSHA256(_ value: String) -> Bool {
    value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
  }
}
