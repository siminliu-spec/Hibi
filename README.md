# Hibi 日々

One day at a time, floating on water.

Hibi is a small almanac that lives in the macOS menu bar. Click the fish and a panel opens with today: the date, the lunar date, one thing the day is for and one it is not. Koi swim under the words, and their ripples bend them. Tap the water and the fish scatter, then come back for food.

Nothing changes at midnight: a day starts at 4:00 in the morning. The first time you open Hibi on a new day, yesterday is still there, under a morning fog: tap the water to let it go, and today rises up.

## Install

Hibi isn't signed with an Apple Developer ID yet, so the first time you open it, macOS asks you to confirm.

1. Download `Hibi.zip` from Releases and unzip it.
2. Drag **Hibi** into your **Applications** folder.
3. Open Hibi. macOS says it can't check it for malicious software: click **Done**.
4. Open **System Settings → Privacy & Security**, scroll down to the message about Hibi, and click **Open Anyway**. Confirm with your password, then click **Open**.
   On macOS 14 Sonoma or earlier: Control-click Hibi in Applications, choose **Open**, then **Open** again.
5. A fish appears in the menu bar and the panel opens. From then on, click the fish or press **⌃⌘H**.

If macOS says Hibi "is damaged and can't be opened", open Terminal and run:

```
xattr -dr com.apple.quarantine /Applications/Hibi.app
```

To make a release yourself: in Xcode, **Product → Archive → Distribute App → Custom → Copy App**, then compress the exported app in Finder.

## Run it from Xcode

1. Open `Hibi.xcodeproj` in Xcode 16 or later.
2. Press ⌘R. A fish appears in the menu bar; click it.
   If Xcode asks for a signing team, choose your Personal Team under *Signing & Capabilities*.

Requires macOS 13 Ventura or later. Click the fish (or press ⌃⌘H) to open the panel; right-click it for Paper (Jade / Azure), Motion, Sound, Open at Login and Quit. Debug builds also have *Preview a New Morning*.

## How it is built

| File | What it does |
| --- | --- |
| `Hibi/Web/panel.html` | The whole panel — paper, koi, ripples, words, the morning fog — as one self-contained page with its images, sounds and the Inter font inside. |
| `Hibi/PanelController.swift` | The borderless, rounded window under the menu-bar icon that shows the page, and passes settings to it and back. |
| `Hibi/AppDelegate.swift` | The menu-bar icon and its menu. |
| `Hibi/Prefs.swift` | What Hibi remembers: paper, motion, sound, and the last day you let in. |
| `Hibi/HotKey.swift` | The ⌃⌘H shortcut. |

To change the panel, replace `Hibi/Web/panel.html` and run again.

### 宜 · 忌

Each day's *A day for* and *Not for today* start from the real Chinese almanac: [lunar-javascript](https://github.com/6tail/lunar-javascript) computes the day's traditional 宜 and 忌, on the device. The panel never shows those old words. Each one has two modern versions in `Hibi-宜忌词典.xlsx`: a way to take care of yourself when it is a 宜, and a kind of hustle when it is a 忌. One of each is picked per day, the same on every Mac, avoiding what the past week already showed.

The panel follows the Mac's *Reduce Motion* setting: the fish swim slowly, the words only ripple when you tap, and the morning fog simply fades.

## Credits

- Songti SC, from macOS. Inter by Rasmus Andersson, bundled under the SIL Open Font License 1.1 (`Hibi/Web/Inter-OFL.txt`).
- Water sounds made with ElevenLabs (elevenlabs.io).
- Almanac calculations: lunar-javascript by 6tail, MIT License (`Hibi/Web/lunar-javascript-MIT.txt`).
- Koi illustration: *source and licence to be added.*
