# TextF

TextF is a native macOS menu bar app that captures selected text from other apps and shows it in a floating window.

Select text anywhere, then press your configured global hotkey (default: `Command + Shift + F`).

## Features

- Configurable global hotkey (default: `Command + Shift + F`, persisted locally)
- Floating panel (borderless, draggable around the text area edges, top-left custom close button, closable with `Command + W`, resizable, always on top, opens near mouse pointer)
- Multiple floating panels: each hotkey trigger opens a new window
- Editable text area inside each floating panel
- Panel size limits: minimum `300 x 400`, maximum `600 x 800`
- In-panel zoom: `Command + +` / `Command + -`, reset with `Command + 0` (default font size: `12`, persisted locally)
- Status bar menu:
  - `Show Selected Text`
  - `Set Hotkey`
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
3. Press your configured global hotkey (default: `Command + Shift + F`)
4. Selected text appears in a new floating panel (you can trigger repeatedly to open multiple windows)
5. You can edit the captured text directly inside the floating panel
6. In the floating panel, use `Command + +` / `Command + -` to adjust font size
7. Use `Command + 0` to reset font size to `12`
8. Drag the panel from any non-text area around the content (top/left/right/bottom edges)
9. Close the panel with `Command + W` or the top-left close button

You can also click the menu bar item `TextF` and choose `Show Selected Text`.
To change the global hotkey, open `TextF` -> `Set Hotkey (...)`; settings are saved in local `UserDefaults`.

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
