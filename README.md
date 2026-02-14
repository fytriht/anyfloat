# TextF

TextF is a native macOS menu bar app that captures selected text from other apps and shows it in a floating window.

Select text anywhere, then press `Command + Shift + F`.

## Features

- Global hotkey: `Command + Shift + F`
- Floating panel (draggable, closable, always on top)
- In-panel zoom: `Command + +` / `Command + -`, reset with `Command + 0` (default font size: `12`, persisted locally)
- Status bar menu:
  - `Show Selected Text`
  - `Debug Panel`
  - `Quit TextF`
- Multi-strategy text extraction for better compatibility:
  - Accessibility selected-text APIs
  - Range-based extraction fallback
  - Last-resort copy (`Command + C`) with pasteboard restore

## Requirements

- macOS 13.0+
- Xcode Command Line Tools (`swift` command available)
- Accessibility permission for TextF

## Build and Run (SwiftPM)

```bash
cd .
swift build -c release
./.build/release/TextFApp
```

## Build `.app` Bundle

```bash
cd .
./scripts/package_app.sh
```

Output app bundle:

```text
dist/TextFApp.app
```

Signing behavior:

- Uses `Apple Development` identity if available
- Falls back to ad-hoc signing when no identity is found

## First Launch Setup

TextF requires Accessibility access to read selected text from other apps.

1. Open `System Settings`
2. Go to `Privacy & Security` -> `Accessibility`
3. Enable `TextFApp`

If permission is newly granted, quit and relaunch TextF.

## Usage

1. Launch TextF
2. Select text in another app
3. Press `Command + Shift + F`
4. Selected text appears in the floating panel
5. In the floating panel, use `Command + +` / `Command + -` to adjust font size
6. Use `Command + 0` to reset font size to `12`

You can also click the menu bar item `TextF` and choose `Show Selected Text`.

## Troubleshooting

- `No selected text` appears:
  - Confirm Accessibility permission is enabled
  - Confirm target app/window is focused
  - Re-select text and trigger hotkey again
- Hotkey does not trigger:
  - Check for shortcut conflicts with other tools
  - Relaunch TextF
- Some apps still fail:
  - Open `TextF` -> `Debug Panel` to inspect AX/focus state

## Project Layout

```text
Sources/TextFApp/main.swift   # app entry, hotkey, AX reader, floating panel
scripts/package_app.sh        # build + app bundle packaging + signing
Package.swift                 # SwiftPM manifest
```

## License

This project is licensed under the GNU General Public License v3.0.
See `LICENSE` for details.
