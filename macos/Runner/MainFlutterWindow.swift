import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var titleBarChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // The title bar paints in the system window colour, which cuts a band
    // across the top of the app's own surface. Hiding it and running the
    // Flutter view the full height of the window leaves only the traffic
    // lights floating over the sidebar.
    //
    // The title bar view stays above the content and keeps handling drags, so
    // nothing in the strip it covers is clickable — that strip is reported to
    // Dart below and reserved there as MediaQuery top padding.
    self.styleMask.insert(.fullSizeContentView)
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden

    let channel = FlutterMethodChannel(
      name: "rss_reader/title_bar",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getHeight":
        result(self?.titleBarHeight ?? 0)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.titleBarChannel = channel

    for name in [
      NSWindow.didEnterFullScreenNotification,
      NSWindow.didExitFullScreenNotification,
    ] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(sendTitleBarHeight), name: name, object: self)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  /// Height of the strip the title bar covers, in points.
  ///
  /// Zero in full screen, where the title bar is an auto-hiding overlay that
  /// covers the content only while the pointer is at the top edge. Measured
  /// rather than assumed otherwise, so a window that gains a toolbar reports
  /// the taller bar it then has.
  private var titleBarHeight: Double {
    guard !styleMask.contains(.fullScreen), let contentView = contentView else {
      return 0
    }
    return Double(contentView.bounds.height - contentLayoutRect.height)
  }

  @objc private func sendTitleBarHeight() {
    titleBarChannel?.invokeMethod("setHeight", arguments: titleBarHeight)
  }
}
