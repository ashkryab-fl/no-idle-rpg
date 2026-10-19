import Cocoa
import FlutterMacOS
import CoreGraphics
import IOKit

class MainFlutterWindow: NSWindow {
  private var channel: FlutterMethodChannel?
  private var pointerTimer: Timer?
  private var expanded = false
  private var topmost = true
  private var windowScale: CGFloat = 1
  private var screenIndex = 0
  private var closePending = false
  private var lastVisibleFrame: NSRect?
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func awakeFromNib() {
    let controller = FlutterViewController()
    contentViewController = controller
    controller.backgroundColor = .clear
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    styleMask = [.borderless]
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    level = .floating
    isReleasedWhenClosed = false
    RegisterGeneratedPlugins(registry: controller)
    channel = FlutterMethodChannel(name: "idle_companion/desktop", binaryMessenger: controller.engine.binaryMessenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      switch call.method {
      case "idleSeconds":
        // .null means a null event, not "any input". Query only timestamps.
        let types: [CGEventType] = [.keyDown, .flagsChanged, .mouseMoved,
          .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
          .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        let seconds = types.map {
          CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }.min() ?? 0
        // Sandboxed macOS versions may return boot-age CG timestamps.
        // IOHIDSystem exposes a duration only, with no keyboard/mouse contents.
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        var hidSeconds: Double? = nil
        if service != 0 {
          if let property = IORegistryEntryCreateCFProperty(service, "HIDIdleTime" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? NSNumber {
            hidSeconds = property.doubleValue / 1_000_000_000
          }
          IOObjectRelease(service)
        }
        result(min(seconds, hidSeconds ?? seconds))
      case "configure":
        let arguments = call.arguments as? [String: Any] ?? [:]
        self.expanded = arguments["expanded"] as? Bool ?? false
        self.topmost = arguments["alwaysOnTop"] as? Bool ?? true
        let scale = arguments["scale"] as? Double ?? 1
        self.windowScale = scale.isFinite ? CGFloat(min(3, max(0.5, scale))) : 1
        self.level = self.topmost ? .floating : .normal
        self.positionOverlay()
        self.updateClickThrough()
        result(nil)
      case "cancelClose":
        closePending = false
        if AppDelegate.waitingForSave { NSApp.reply(toApplicationShouldTerminate: false) }
        AppDelegate.waitingForSave = false
        result(nil)
      case "quit":
        result(nil)
        AppDelegate.allowTermination = true
        if AppDelegate.waitingForSave {
          NSApp.reply(toApplicationShouldTerminate: true)
        } else {
          NSApp.terminate(nil)
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
    NotificationCenter.default.addObserver(self, selector: #selector(positionOverlay), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    pointerTimer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.updateClickThrough() }
    RunLoop.main.add(pointerTimer!, forMode: .common)
    positionOverlay()
    super.awakeFromNib()
  }

  @objc private func positionOverlay() {
    guard !NSScreen.screens.isEmpty else { return }
    // Keep the chosen screen after topology changes; fall back to primary.
    screenIndex = min(screenIndex, NSScreen.screens.count - 1)
    let visible = NSScreen.screens[screenIndex].visibleFrame
    lastVisibleFrame = visible
    let availableWidth = visible.width - 24
    let availableHeight = visible.height - 24
    let scale = min(windowScale, availableWidth / 400, availableHeight / 190)
    // The popup overlays the scene; it never reserves scene space.
    let width = expanded ? availableWidth : max(400, 400 * scale)
    // Keep room for speech at its default text and container size.
    let height = expanded ? availableHeight : min(availableHeight, max(190, 190 * scale))
    setFrame(NSRect(x: visible.maxX - width - 12, y: visible.minY + 12, width: width, height: height), display: true)
  }
  private func updateClickThrough() {
    if NSScreen.screens.indices.contains(screenIndex),
       NSScreen.screens[screenIndex].visibleFrame != lastVisibleFrame {
      positionOverlay()
    }
    let local = NSPoint(x: NSEvent.mouseLocation.x - frame.minX, y: frame.maxY - NSEvent.mouseLocation.y)
    let scale = min(windowScale, frame.width / 400, frame.height / 190)
    let menu = NSRect(x: frame.width - 46, y: frame.height - 190 * scale + 8, width: 38, height: 38)
    let panelHeight = min(418, frame.height - 16)
    let panelBottom = min(194, max(8, frame.height - panelHeight - 8))
    let panel = NSRect(x: frame.width - 392, y: frame.height - panelBottom - panelHeight, width: 384, height: panelHeight)
    let interactive = menu.contains(local) || (expanded && panel.contains(local))
    ignoresMouseEvents = !interactive
  }
  func requestClose() {
    if closePending { return }
    closePending = true
    channel?.invokeMethod("closeRequested", arguments: nil)
  }
  deinit { pointerTimer?.invalidate(); NotificationCenter.default.removeObserver(self) }
}
