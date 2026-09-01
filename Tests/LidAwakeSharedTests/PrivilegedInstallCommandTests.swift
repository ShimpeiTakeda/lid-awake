import Testing

@testable import LidAwakeShared

@Suite("POSIXShell")
struct POSIXShellTests {
  @Test("Quotes spaces and single quotes as one shell word")
  func quote() {
    #expect(POSIXShell.quote("/tmp/Lid Awake.app") == "'/tmp/Lid Awake.app'")
    #expect(POSIXShell.quote("a'b") == "'a'\\''b'")
  }
}

@Suite("PrivilegedInstallCommand")
struct PrivilegedInstallCommandTests {
  private let digest = String(repeating: "a", count: 64)

  @Test("Changes system paths only after digest verification in root staging")
  func verifiedStagingOrder() throws {
    let command = try makeCommand().render()
    let stageRange = try #require(command.range(of: "mktemp -d"))
    let digestRange = try #require(command.range(of: "helper_digest="))
    let bootoutRange = try #require(command.range(of: "launchctl bootout"))
    let targetRange = try #require(command.range(of: AppConstants.helperInstallPath))

    #expect(stageRange.lowerBound < digestRange.lowerBound)
    #expect(digestRange.lowerBound < bootoutRange.lowerBound)
    #expect(bootoutRange.lowerBound < targetRange.lowerBound)
    #expect(command.contains("trap cleanup EXIT HUP INT TERM"))
    #expect(command.contains("pmset -a disablesleep 0"))
  }

  @Test("Quotes source paths against command injection")
  func quotesSourcePaths() throws {
    let command = try PrivilegedInstallCommand(
      helperSourcePath: "/tmp/a'; touch /tmp/pwned; echo '",
      plistSourcePath: "/tmp/Lid Awake/helper.plist",
      helperSHA256: digest,
      plistSHA256: digest
    ).render()
    #expect(command.contains(POSIXShell.quote("/tmp/a'; touch /tmp/pwned; echo '")))
    #expect(command.contains(POSIXShell.quote("/tmp/Lid Awake/helper.plist")))
  }

  @Test("Renders a command accepted by the macOS POSIX shell parser")
  func shellSyntax() throws {
    let command = try makeCommand().render()
    let result = try SynchronousProcessRunner.run(
      executable: "/bin/sh",
      arguments: ["-n", "-c", command],
      timeout: 2
    )
    #expect(result.terminationStatus == 0)
    #expect(result.standardError.isEmpty)
  }

  @Test("Rejects a non-SHA-256 value before command rendering")
  func rejectsInvalidDigest() {
    #expect(throws: PrivilegedInstallCommand.ValidationError.invalidSHA256) {
      try PrivilegedInstallCommand(
        helperSourcePath: "/tmp/helper",
        plistSourcePath: "/tmp/helper.plist",
        helperSHA256: "invalid; /usr/bin/true",
        plistSHA256: digest
      ).render()
    }
  }

  private func makeCommand() -> PrivilegedInstallCommand {
    PrivilegedInstallCommand(
      helperSourcePath: "/tmp/Lid Awake/helper",
      plistSourcePath: "/tmp/Lid Awake/helper.plist",
      helperSHA256: digest,
      plistSHA256: digest
    )
  }
}
