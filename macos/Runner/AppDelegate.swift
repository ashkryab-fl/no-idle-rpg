import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  static var allowTermination = false
  static var waitingForSave = false
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if AppDelegate.allowTermination { return .terminateNow }
    AppDelegate.waitingForSave = true
    (mainFlutterWindow as? MainFlutterWindow)?.requestClose()
    return .terminateLater
  }
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { false }
}
