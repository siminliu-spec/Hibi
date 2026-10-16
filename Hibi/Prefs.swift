import Foundation

/// The few things Hibi remembers. The page receives them when it loads and reports back whenever one changes.
@MainActor
enum Prefs {
    private static let store = UserDefaults.standard

    /// Paper: "jade" (青) or "azure" (蓝).
    static var theme: String {
        get { store.string(forKey: "theme") ?? "jade" }
        set { store.set(newValue, forKey: "theme") }
    }

    static var motion: Bool {
        get { store.object(forKey: "motion") as? Bool ?? true }
        set { store.set(newValue, forKey: "motion") }
    }

    static var sound: Bool {
        get { store.object(forKey: "sound") as? Bool ?? true }
        set { store.set(newValue, forKey: "sound") }
    }

    /// The last day that was let in, as yyyy-MM-dd (a day starts at 4:00). When it is before today, the panel opens under the morning fog.
    static var seenDay: String? {
        get { store.string(forKey: "seenDay") }
        set { store.set(newValue, forKey: "seenDay") }
    }

    /// Set after the very first launch, when the panel opens by itself once so the fish in the menu bar is easy to find.
    static var hasLaunchedBefore: Bool {
        get { store.bool(forKey: "hasLaunchedBefore") }
        set { store.set(newValue, forKey: "hasLaunchedBefore") }
    }

    /// "Don't ask again" on the Move to Applications prompt.
    static var skipMovePrompt: Bool {
        get { store.bool(forKey: "skipMovePrompt") }
        set { store.set(newValue, forKey: "skipMovePrompt") }
    }
}
