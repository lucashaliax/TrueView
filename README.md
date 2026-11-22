# TrueView

**English** · [Português](README.pt-BR.md)

![TrueView — True color. Automatically.](Promo/01-hero.png)

A macOS menu bar app that automatically turns off **True Tone** (and Night Shift) when you open a photo editing app — Lightroom Classic, Lightroom, Photoshop, Photos, Capture One and more — and restores everything when you close it.

## Screenshots

![Open. Edit. Done.](Promo/02-how-it-works.png)

![See your photos as they really are.](Promo/03-true-color.png)

![You're in control.](Promo/04-control.png)

## Download

Grab **TrueView.zip** from the [latest release](https://github.com/lucashaliax/TrueView/releases/latest), unzip it and drag `TrueView.app` to `/Applications`.

TrueView isn't notarized by Apple, so macOS blocks it the first time you open it. To allow it:

1. Open TrueView once. macOS will say it can't verify the developer; click **Done**.
2. Go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway** next to TrueView.

Or run this once in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/TrueView.app
```

## Features

- Watches when your chosen apps open and close (or come to the front)
- Turns off True Tone and Night Shift in "edit mode"
- Custom brightness for the built-in display, with a return to your previous level
- Only restores what it changed: if True Tone was already off, it stays off
- Adjustable delay before restoring, so the screen doesn't flicker when you switch apps
- Recovers the display state if the app is force-quit
- Configurable app list (add from Applications, from running apps, or by dragging)
- Open at login, notifications, English/Portuguese interface
- Updates itself: Check for Updates in About (and a daily automatic check) downloads the latest release, verifies its signature and relaunches
- Liquid Glass interface

## Requirements

- macOS 26 or later, Apple Silicon
- Xcode Command Line Tools (`xcode-select --install`)

## Build from source

```bash
./build.sh          # build, install in /Applications, relaunch, check resource use
./build.sh --zip    # same, plus build/release/TrueView.zip for a GitHub release
```

The app is built in `~/Library/Developer/TrueView-build` (outside `~/Documents`, whose iCloud sync breaks code signing) and signed with your Apple Development certificate (`SIGN_ID` to choose another identity). Signing with a team is what lets the updater check that an update comes from the same developer. Every build ends with `tools/check_resources.sh`, which measures memory, idle CPU, wakeups and leaks.

The icon is drawn in code (`Icon/IconRenderer.swift`); to regenerate the `.icns`, run the renderer and then `iconutil`.

The promo images are generated in code too:

```bash
swiftc -O -swift-version 5 Promo/PromoRenderer.swift -o build/promo-render && build/promo-render
```

## Note

True Tone, Night Shift and brightness are controlled through private Apple frameworks (`CoreBrightness`, `DisplayServices`), loaded at runtime. They work on current macOS but may change in future versions — which is also why the app can't be distributed through the App Store.

---

Developed by Lucas Haliax
