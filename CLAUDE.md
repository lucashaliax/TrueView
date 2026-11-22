# TrueView

A macOS menu bar app (Liquid Glass UI) that turns off True Tone and Night Shift, and optionally sets a custom brightness, while photo editing apps (Lightroom Classic, Lightroom, Photoshop, Photos, Capture One…) are open or in front. When they close, it restores only what it changed. Published at https://github.com/lucashaliax/TrueView (public, releases with `TrueView.zip`). User-facing docs: `README.md` / `README.pt-BR.md`. It is the reference project for how apps are published (see the global `~/.claude/CLAUDE.md`).

## Layout

- `Sources/App.swift`: entry point and menu bar setup. `MenuPanel.swift`: the menu bar panel with toggles. `SettingsView.swift`, `Settings.swift`. `Glass.swift`: shared Liquid Glass styling.
- `Sources/AutomationEngine.swift`: watches the chosen apps, enters/leaves "edit mode", saves the display state before changing it, restores it after an adjustable delay (avoids flicker when switching apps), and recovers the state after a force quit.
- `Sources/DisplayControl.h/.m`: Objective-C bridge to the private frameworks `CoreBrightness` (True Tone, Night Shift) and `DisplayServices` (built-in brightness), loaded at runtime. If an API is missing, the calls return "unsupported" instead of crashing. This is why the app can't go on the App Store.
- `Sources/Updater.swift`: self-update from GitHub releases (copied from Floatr).
- `Icon/IconRenderer.swift`: draws the icon in code → `Icon/TrueView.icns` (via `iconutil`).
- `Promo/PromoRenderer.swift`: renders the README images (2880×1800).

## Build

- `./build.sh`: no Xcode project. It compiles with `clang` + `swiftc` into `~/Library/Developer/TrueView-build`, writes the Info.plist itself, runs `xattr -cr`, signs with `Apple Development` (team WLWCRYCLRT), installs to `/Applications`, relaunches, then runs `tools/check_resources.sh`. Report its numbers after each build.
- `./build.sh --zip` also writes `build/release/TrueView.zip`. `./build.sh --no-install` only builds. `VERSION=0.0.1 ./build.sh --no-install` builds an older-looking copy for testing updates.
- Version and build number are the `VERSION` / `BUILD_NUMBER` defaults at the top of `build.sh`. Bundle id `local.trueview.app`, macOS 26+, Apple Silicon only.
- New machine: needs Xcode (or Command Line Tools) and the Apple Development certificate in the Keychain (sign in with the Apple ID in Xcode). Without it, use `SIGN_ID=-` to build ad hoc, but then the updater check fails.

## Decisions

- Signed with the team, not ad hoc, so the updater can verify that an update comes from the same developer. Because of the signature change in 0.2, macOS may ask again for permissions (notifications, open at login).
- Menu bar toggles instead of an activation history (removed on purpose).
- Interface in English by default, Portuguese in settings.
- Update test without UI: `open -a TrueView --args -TrueViewRunUpdate YES`.

## Status

- Current release: 0.2 (self-update from GitHub, signed with the team).
- No open tasks. Bugs are reported by the user as they find them.
