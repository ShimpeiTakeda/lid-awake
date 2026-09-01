import Foundation
import Testing

@testable import LidAwakeShared

@Suite("SynchronousProcessRunner")
struct ProcessRunnerTests {
  @Test("stdoutとstderrと終了コードを保持する")
  func capturesResult() throws {
    let result = try SynchronousProcessRunner.run(
      executable: "/bin/sh",
      arguments: ["-c", "printf output; printf error >&2; exit 7"],
      timeout: 2
    )
    #expect(result.terminationStatus == 7)
    #expect(result.standardOutput == "output")
    #expect(result.standardError == "error")
  }

  @Test("pipe容量を超える出力でも停止しない")
  func capturesLargeOutput() throws {
    let result = try SynchronousProcessRunner.run(
      executable: "/bin/sh",
      arguments: ["-c", "/usr/bin/yes 0123456789 | /usr/bin/head -c 200000"],
      timeout: 2
    )
    #expect(result.terminationStatus == 0)
    #expect(result.standardOutput.utf8.count == 200_000)
  }

  @Test("timeoutしたprocessを終了して失敗を返す")
  func timesOut() {
    #expect(throws: ProcessRunnerError.self) {
      try SynchronousProcessRunner.run(
        executable: "/bin/sleep",
        arguments: ["2"],
        timeout: 0.02
      )
    }
  }

  @Test("0以下のtimeoutを拒否する")
  func invalidTimeout() {
    #expect(throws: ProcessRunnerError.invalidTimeout) {
      try SynchronousProcessRunner.run(
        executable: "/usr/bin/true",
        arguments: [],
        timeout: 0
      )
    }
  }
}
