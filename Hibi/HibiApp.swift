import SwiftUI

/// Hibi lives in the menu bar: no Dock icon, no windows of its own.
/// Everything happens in AppDelegate (the menu-bar icon) and PanelController (the panel under it).
@main
struct HibiApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
