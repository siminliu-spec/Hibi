import AppKit
import IOKit.ps
import WebKit

/// The panel under the menu-bar icon: a borderless, rounded window holding the page that draws the pond (Web/panel.html).
/// The page does all the drawing; this class only shows and hides it, and passes settings back and forth.
@MainActor
final class PanelController: NSObject {
    static let size = NSSize(width: 340, height: 448)
    static let cornerRadius: CGFloat = 24
    private static let gapBelowMenuBar: CGFloat = 6

    private let panel: HibiPanel
    private let webView: WKWebView
    private let content: WKUserContentController
    private let page: String
    private weak var anchor: NSStatusBarButton?
    private var outsideClickMonitor: Any?
    private var keyMonitor: Any?
    private var powerTimer: Timer?

    var isShown: Bool { panel.isVisible }

    /// - Parameter page: the HTML file in the app bundle (Web/panel.html).
    init(page: String = "panel") {
        self.page = page
        let content = WKUserContentController()
        self.content = content
        let config = WKWebViewConfiguration()
        config.userContentController = content
        config.mediaTypesRequiringUserActionForPlayback = []   // the water sound plays on a click
        webView = WKWebView(frame: NSRect(origin: .zero, size: PanelController.size), configuration: config)
        panel = HibiPanel(contentRect: NSRect(origin: .zero, size: PanelController.size),
                          styleMask: [.borderless, .nonactivatingPanel],
                          backing: .buffered,
                          defer: false)
        super.init()

        content.add(MessageProxy(owner: self), name: "hibi")
        webView.navigationDelegate = self
        webView.autoresizingMask = [.width, .height]

        // Rounded corners and a hairline edge, like the panel in the Figma file.
        let container = NSView(frame: NSRect(origin: .zero, size: Self.size))
        container.wantsLayer = true
        container.layer?.cornerRadius = Self.cornerRadius
        container.layer?.cornerCurve = .continuous
        container.layer?.masksToBounds = true
        container.layer?.borderWidth = 0.5
        container.layer?.borderColor = NSColor.black.withAlphaComponent(0.12).cgColor
        container.addSubview(webView)

        panel.contentView = container
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.acceptsMouseMovedEvents = true            // the small ripples that follow the pointer
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow

        load()
    }

    // MARK: Showing and hiding

    func toggle(below button: NSStatusBarButton) {
        if panel.isVisible { hide() } else { show(below: button) }
    }

    func show(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        anchor = button
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? buttonRect

        // Centred under the icon, kept 8 pt inside the screen edge.
        var x = buttonRect.midX - Self.size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - Self.size.width - 8)
        let y = buttonRect.minY - Self.size.height - Self.gapBelowMenuBar
        panel.setFrame(NSRect(x: x.rounded(), y: y.rounded(), width: Self.size.width, height: Self.size.height), display: false)

        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(webView)
        panel.invalidateShadow()
        button.highlight(true)
        run("window.yuliResume && window.yuliResume()")   // the fish swim again; if the day has changed, the fog is waiting
        run("window.yuliFocus && window.yuliFocus()")     // keyboard and VoiceOver land in the panel: on the fog's button, or on today
        reportPower()
        powerTimer?.invalidate()
        powerTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.reportPower() }
        }
        startMonitors()
    }

    func hide() {
        guard panel.isVisible else { return }
        run("window.yuliPause && window.yuliPause()")     // nothing animates while the panel is closed
        panel.orderOut(nil)
        anchor?.highlight(false)
        powerTimer?.invalidate()
        powerTimer = nil
        stopMonitors()
    }

    // MARK: Talking to the page

    func run(_ script: String) {
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    func setTheme(_ name: String) { run("window.yuliTheme && window.yuliTheme('\(name)')") }
    func setMotion(_ on: Bool) { run("window.yuliSetMotion && window.yuliSetMotion(\(on))") }
    func setSound(_ on: Bool) { run("window.yuliSetSound && window.yuliSetSound(\(on))") }
    func previewNewMorning() { run("window.yuliPreviewMorning && window.yuliPreviewMorning()") }

    /// On battery or in Low Power Mode the page draws at 30 fps instead of 60.
    private func reportPower() {
        run("window.yuliSetPower && window.yuliSetPower(\(Self.isSavingPower()))")
    }

    private static func isSavingPower() -> Bool {
        if ProcessInfo.processInfo.isLowPowerModeEnabled { return true }
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let source = IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() else { return false }
        return (source as String) == "Battery Power"   // kIOPMBatteryPowerKey
    }

    /// The page reports a change, e.g. {"seen": "2026-10-16"} after the fog is let go.
    fileprivate func receive(_ body: Any) {
        guard let message = body as? [String: Any] else { return }
        if let seen = message["seen"] as? String { Prefs.seenDay = seen }
        if let theme = message["theme"] as? String { Prefs.theme = theme }
        if let motion = message["motion"] as? Bool { Prefs.motion = motion }
        if let sound = message["sound"] as? Bool { Prefs.sound = sound }
    }

    private func load() {
        // Hand the page what Hibi remembers before any of its own script runs.
        content.removeAllUserScripts()
        content.addUserScript(WKUserScript(source: Self.bootScript(), injectionTime: .atDocumentStart, forMainFrameOnly: true))
        guard let url = Bundle.main.url(forResource: page, withExtension: "html") else {
            assertionFailure("\(page).html is missing from the app bundle")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private static func bootScript() -> String {
        var state: [String: Any] = ["theme": Prefs.theme, "motion": Prefs.motion, "sound": Prefs.sound]
        if let seen = Prefs.seenDay { state["seen"] = seen }
        let json = (try? JSONSerialization.data(withJSONObject: state)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        // No browser right-click menu (Reload, Inspect…) inside the panel.
        // html.app: show only the panel, edge to edge (the window draws the corners).
        return "window.HIBI=\(json);if(document.documentElement)document.documentElement.classList.add('app');document.addEventListener('contextmenu',function(e){e.preventDefault()});"
    }

    // MARK: Closing when you click elsewhere or press Esc

    private func startMonitors() {
        stopMonitors()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.keyCode == 53, self.panel.isVisible else { return event }   // 53 = Esc
            self.hide()
            return nil
        }
    }

    private func stopMonitors() {
        if let monitor = outsideClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }
        outsideClickMonitor = nil
        keyMonitor = nil
    }
}

extension PanelController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !panel.isVisible { run("window.yuliPause && window.yuliPause()") }
    }

    /// If macOS ever stops the page's process, start it again.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        load()
    }
}

/// A panel that can take keyboard focus (Tab and Enter reach the fog's button) without making Hibi the active app.
final class HibiPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Receives messages from the page. Kept separate so the web view doesn't hold on to the controller.
@MainActor
private final class MessageProxy: NSObject, WKScriptMessageHandler {
    weak var owner: PanelController?

    init(owner: PanelController) {
        self.owner = owner
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        owner?.receive(message.body)
    }
}
