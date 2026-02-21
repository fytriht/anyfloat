# AnyFloat

AnyFloat is a native macOS menu bar app built around one idea: quickly present anything in a floating window.

Press your configured global hotkey (default: `Command + Shift + F`) to bring content into view. Today it supports selected text capture and blank-window quick input, while screenshot-based content support is planned next.

## Features

- Configurable global hotkey (default: `Command + Shift + F`, persisted locally)
- Launch at login (enabled by default, configurable from Preferences)
- Floating panel (borderless, draggable around the text area edges, top-left custom close button, closable with `Command + W`, resizable, always on top, opens near mouse pointer)
- Multiple floating panels: each hotkey trigger opens a new window
- Editable text area inside each floating panel (window height auto-adjusts to keep content visible while typing; once you manually resize a panel, that panel keeps manual size)
- Panel size limits: minimum `300 x 120`, maximum `600 x 800`
- In-panel zoom: `Command + +` / `Command + -`, reset with `Command + 0` (default font size: `12`, persisted locally)
- Status bar menu:
  - `Show Selected Text`
  - `Preferences...` (hotkey + launch at login)
  - `Quit AnyFloat`
- Multi-strategy text extraction for better compatibility:
  - Accessibility selected-text APIs
  - Range-based extraction fallback
  - Last-resort copy (`Command + C`) with pasteboard restore

## Requirements

- macOS 13.0+
- Xcode Command Line Tools (`swift` command available)
- Full Xcode app is required for `scripts/package_app.sh` (`xcodebuild archive`)
- Accessibility permission for AnyFloat

## Build and Run (SwiftPM)

```bash
cd .
swift build -c release
./.build/release/AnyFloat
```

## Build and Run (Xcode)

1. Open `/Users/zhi/Developer/AnyFloat/AnyFloat.xcodeproj`
2. Select the `AnyFloat` scheme
3. Run (`Command + R`)

Project notes:

- App target uses existing source file `Sources/AnyFloatApp/AnyFloatApp.swift`
- App `Info.plist` path is `XcodeSupport/Info.plist`
- `LSUIElement` is enabled for menu bar app behavior

## Build `.app` (Default)

```bash
cd .
./scripts/package_app.sh
```

Default output artifacts:

```text
dist/AnyFloat.app
dist/AnyFloat.xcarchive
```

## Build `.dmg` (Optional)

```bash
cd .
./scripts/package_app.sh --dmg
```

Additional output artifact:

```text
dist/AnyFloat.dmg
```

Install flow for end users:

1. Open `dist/AnyFloat.dmg`
2. Drag `AnyFloat.app` to `Applications`

Signing behavior:

- Uses `Apple Development` identity if available
- Falls back to ad-hoc signing when no identity is found

## First Launch Setup

AnyFloat requires Accessibility access to read selected text from other apps.

1. Open `System Settings`
2. Go to `Privacy & Security` -> `Accessibility`
3. Enable `AnyFloat`

If permission is newly granted, quit and relaunch AnyFloat.

## Usage

1. Launch AnyFloat
2. Select text in another app
3. Press your configured global hotkey (default: `Command + Shift + F`)
4. Selected text appears in a new floating panel (you can trigger repeatedly to open multiple windows)
5. You can edit the captured text directly inside the floating panel; panel height expands/shrinks with content (within min/max limits and visible screen area)
6. If you manually resize a panel, that panel switches to manual sizing and no longer auto-adjusts height
7. If no text is selected, an empty editor opens for immediate typing; if text is captured, the panel keeps the editor unfocused on open
8. In the floating panel, use `Command + +` / `Command + -` to adjust font size
9. Use `Command + 0` to reset font size to `12`
10. Drag the panel from any non-text area around the content (top/left/right/bottom edges)
11. Close the panel with `Command + W` or the top-left close button

You can also click the menu bar item `AnyFloat` and choose `Show Selected Text`.
To change the global hotkey or startup behavior, open `AnyFloat` -> `Preferences...` (or press `Command + ,`).
Both settings are saved in local `UserDefaults`.

## Troubleshooting

- Hotkey does not trigger:
  - Check for shortcut conflicts with other tools
  - Relaunch AnyFloat
- Some apps still fail:
  - Confirm Accessibility permission is granted to `AnyFloat`

## Project Layout

```text
Sources/AnyFloatApp/AnyFloatApp.swift   # app entry, hotkey, AX reader, floating panel
scripts/package_app.sh        # xcodebuild archive + app export + signing (optional dmg creation)
Package.swift                 # SwiftPM manifest
```

## License

This project is licensed under the GNU General Public License v3.0.
See `LICENSE` for details.
