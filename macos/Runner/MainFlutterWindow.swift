import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
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
    // nothing in the top `macOSTitleBarHeight` of the window is clickable —
    // that strip is reserved as MediaQuery top padding on the Dart side.
    self.styleMask.insert(.fullSizeContentView)
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
