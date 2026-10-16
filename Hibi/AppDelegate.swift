import AppKit
import Carbon.HIToolbox
import ServiceManagement
import os

/// The menu-bar icon. Click: open or close the panel. Right-click (or Control-click): the menu. ⌃⌘H from anywhere: open or close the panel.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: HotKey?
    private lazy var panel = PanelController(page: "panel")
    private let log = Logger(subsystem: "com.siminliu.hibi", category: "app")

    /// A second copy of Hibi tells the first one to open its panel, then quits.
    private static let showPanelNote = Notification.Name("com.siminliu.hibi.showPanel")

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if !DEBUG
        if anotherCopyIsRunning() {
            DistributedNotificationCenter.default().postNotificationName(Self.showPanelNote, object: nil, userInfo: nil, deliverImmediately: true)
            NSApp.terminate(nil)
            return
        }
        if offerToMoveToApplications() { return }
        #endif
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(showPanelFromAnotherCopy(_:)), name: Self.showPanelNote, object: nil)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            // Placeholder: SF Symbol "fish". To use your own icon, add an 18 × 18 pt template image named
            // "MenuBarIcon" to an asset catalog and it will be picked up here.
            if let icon = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "fish", accessibilityDescription: "Hibi") {
                icon.isTemplate = true
                button.image = icon
            } else {
                button.title = "日"
            }
            button.setAccessibilityLabel("Hibi")
            button.toolTip = "Hibi  ⌃⌘H"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
        _ = panel   // load the page now, so it is ready the first time the panel opens

        // ⌃⌘H opens and closes the panel from anywhere (⌥⌘H is taken: it is macOS's "Hide Others").
        hotKey = HotKey(keyCode: kVK_ANSI_H, modifiers: controlKey | cmdKey) { [weak self] in
            self?.togglePanel()
        }
        if hotKey == nil { log.notice("⌃⌘H is already used by another app") }

        // The very first time, open the panel by itself: the icon may be hidden behind the notch,
        // and an app with no Dock icon and no window otherwise looks as if it never started.
        if !Prefs.hasLaunchedBefore {
            Prefs.hasLaunchedBefore = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)   // let the menu bar place the icon first
                self.openPanel()
            }
        }
    }

    /// Opening Hibi again (from Finder, Spotlight or Launchpad) while it is running opens the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openPanel()
        return false
    }

    // MARK: The panel

    private func openPanel() {
        guard let button = statusItem?.button else { return }
        if !panel.isShown { panel.show(below: button) }
    }

    private func togglePanel() {
        guard let button = statusItem?.button else { return }
        panel.toggle(below: button)
    }

    @objc private func showPanelFromAnotherCopy(_ note: Notification) {
        openPanel()
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            panel.hide()
            showMenu()
        } else {
            panel.toggle(below: sender)
        }
    }

    // MARK: The menu

    private func showMenu() {
        guard let item = statusItem else { return }
        item.menu = makeMenu()
        item.button?.performClick(nil)   // opens the menu and waits until it closes
        item.menu = nil                  // so the next left click opens the panel again
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let open = item("Open Hibi", on: false, action: #selector(openPanelFromMenu))
        open.keyEquivalent = "h"
        open.keyEquivalentModifierMask = [.control, .command]
        menu.addItem(open)
        menu.addItem(.separator())

        let papers = NSMenu()
        for (id, title) in [("jade", "Jade 青"), ("azure", "Azure 蓝")] {
            let paper = NSMenuItem(title: title, action: #selector(pickPaper(_:)), keyEquivalent: "")
            paper.target = self
            paper.representedObject = id
            paper.state = Prefs.theme == id ? .on : .off
            papers.addItem(paper)
        }
        let paper = NSMenuItem(title: "Paper", action: nil, keyEquivalent: "")
        paper.submenu = papers
        menu.addItem(paper)

        menu.addItem(item("Motion", on: Prefs.motion, action: #selector(toggleMotion)))
        menu.addItem(item("Sound", on: Prefs.sound, action: #selector(toggleSound)))
        menu.addItem(.separator())

        let login = item("Open at Login", on: false, action: #selector(toggleOpenAtLogin))
        switch SMAppService.mainApp.status {
        case .enabled:
            login.state = .on
        case .requiresApproval:
            login.title = "Open at Login – Approve in System Settings…"
            login.state = .mixed
        default:
            login.state = .off
        }
        menu.addItem(login)

        #if DEBUG
        menu.addItem(.separator())
        menu.addItem(item("Preview a New Morning", on: false, action: #selector(previewNewMorning)))
        #endif

        menu.addItem(.separator())
        menu.addItem(item("About Hibi", on: false, action: #selector(showAbout)))
        menu.addItem(NSMenuItem(title: "Quit Hibi", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func item(_ title: String, on: Bool, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = on ? .on : .off
        return item
    }

    @objc private func openPanelFromMenu() {
        openPanel()
    }

    @objc private func pickPaper(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String else { return }
        Prefs.theme = id
        panel.setTheme(id)
    }

    @objc private func toggleMotion() {
        Prefs.motion.toggle()
        panel.setMotion(Prefs.motion)
    }

    @objc private func toggleSound() {
        Prefs.sound.toggle()
        panel.setSound(Prefs.sound)
    }

    /// The first time, macOS may ask the user to allow Hibi under Login Items: then we take them straight there.
    @objc private func toggleOpenAtLogin() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
                if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            }
        } catch {
            log.error("Open at Login failed: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
        }
    }

    /// Debug builds only: fog over yesterday, so the morning ritual can be tried at any time.
    @objc private func previewNewMorning() {
        openPanel()
        panel.previewNewMorning()
    }

    @objc private func showAbout() {
        activateApp()
        let centred = NSMutableParagraphStyle()
        centred.alignment = .center
        // TODO: add the source and licence of the koi illustration before publishing.
        let credits = NSAttributedString(
            string: "日日是好日 · Every day is a good day.\n\nWater sounds made with ElevenLabs (elevenlabs.io).\nAlmanac calculations: lunar-javascript by 6tail (MIT).",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: centred,
            ])
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: Release builds only: one copy, from Applications

    private func anotherCopyIsRunning() -> Bool {
        guard let id = Bundle.main.bundleIdentifier else { return false }
        let me = ProcessInfo.processInfo.processIdentifier
        return NSRunningApplication.runningApplications(withBundleIdentifier: id).contains { $0.processIdentifier != me }
    }

    /// Run from Downloads (or anywhere outside Applications), Hibi asks once to be moved.
    /// Returns true when the user chose to move it: Hibi then shows the folders and quits.
    private func offerToMoveToApplications() -> Bool {
        let appURL = Bundle.main.bundleURL
        let path = appURL.path
        let inApplications = path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
        guard !inApplications, !Prefs.skipMovePrompt else { return false }

        activateApp()
        let alert = NSAlert()
        alert.messageText = "Move Hibi to your Applications folder?"
        alert.informativeText = "From Applications, Hibi can open at login and is always easy to find. Drag Hibi into Applications, then open it from there. Hibi will quit now so it can be moved."
        alert.addButton(withTitle: "Show in Finder")
        alert.addButton(withTitle: "Not Now")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"
        let response = alert.runModal()
        if alert.suppressionButton?.state == .on { Prefs.skipMovePrompt = true }
        guard response == .alertFirstButtonReturn else { return false }

        // A quarantined download runs from a hidden copy (App Translocation); point at Downloads instead.
        if path.contains("/AppTranslocation/"), let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.open(downloads)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([appURL])
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications"))
        NSApp.terminate(nil)
        return true
    }
}
