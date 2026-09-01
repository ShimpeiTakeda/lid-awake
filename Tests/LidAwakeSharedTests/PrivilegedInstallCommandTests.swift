import Testing

@testable import LidAwakeShared

@Suite("POSIXShell")
struct POSIXShellTests {
  @Test("空白とsingle quoteをshell wordとしてquoteする")
  func quote() {
    #expect(POSIXShell.quote("/tmp/Lid Awake.app") == "'/tmp/Lid Awake.app'")
    #expect(POSIXShell.quote("a'b") == "'a'\\''b'")
  }
}

@Suite("PrivilegedInstallCommand")
struct PrivilegedInstallCommandTests {
  private let digest = String(repeating: "a", count: 64)

  @Test("root stagingでdigest検証後にだけsystem pathを更新する")
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

  @Test("source pathをcommand injectionできない形でquoteする")
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

  @Test("生成commandがmacOSのPOSIX shellとして構文解析できる")
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

  @Test("SHA-256以外の値をcommandへ埋め込まない")
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
