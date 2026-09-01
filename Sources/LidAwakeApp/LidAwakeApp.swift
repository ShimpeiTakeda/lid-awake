import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
  private let model = AppModel()
  private var window: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = NSHostingController(rootView: ContentView(model: model))
    let window = NSWindow(contentViewController: controller)
    window.title = "Lid Awake"
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.setContentSize(NSSize(width: 520, height: 470))
    window.isReleasedWhenClosed = false
    window.center()
    self.window = window

    window.makeKeyAndOrderFront(nil)
    window.delegate = self
    NSApp.activate(ignoringOtherApps: true)

    #if DEBUG
      if ProcessInfo.processInfo.environment["LID_AWAKE_SELF_TEST_CLOSE"] == "1" {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          window.performClose(nil)
        }
      }
    #endif
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    model.disableLeaseImmediately()
    DispatchQueue.main.async { NSApp.terminate(nil) }
    return false
  }

  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    model.disableLeaseImmediately()
    return .terminateNow
  }
}

@main
@MainActor
enum LidAwakeMain {
  static func main() {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    application.setActivationPolicy(.regular)
    application.run()
    _ = delegate
  }
}
