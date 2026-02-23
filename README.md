# AnyFloat

AnyFloat is a native macOS menu bar app built around one idea: quickly capture anything in a floating window.

Press your configured global hotkey (default: `Shift + Option + F`) to bring content into view. Today it supports selected text capture and blank-window quick input, while screenshot-based content support is planned next.

## Features

- Configurable global hotkey (default: `Shift + Option + F`, persisted locally)
- Launch at login (enabled by default, configurable from Preferences)
- Floating panel (borderless, draggable around the text area edges, top-left custom close button, closable with `Command + W`, resizable, always on top, opens near mouse pointer)
- Multiple floating panels: each hotkey trigger opens a new window
- Editable text area inside each floating panel (window height auto-adjusts to keep content visible while typing; once you manually resize a panel, that panel keeps manual size)
- Panel size limits: minimum `300 x 120`, maximum `600 x 800`
- In-panel zoom: `Command + +` / `Command + -`, reset with `Command + 0` (default font size: `12`, persisted locally)
- Status bar menu:
  - `About AnyFloat` (opens macOS standard About panel)
  - `Show Selected Text`
  - `Preferences...` (hotkey + launch at login)
  - `Quit AnyFloat`
- Multi-strategy text extraction for better compatibility:
  - Accessibility selected-text APIs
  - Range-based extraction fallback
  - Last-resort copy (`Command + C`) with pasteboard restore

## Requirements

- macOS 13.0+
- Accessibility permission for AnyFloat

## Contributing

For contributor workflow (debug/release build, Xcode run, packaging, validation checklist), see [`CONTRIBUTING.md`](CONTRIBUTING.md).

## First Launch Setup

AnyFloat requires Accessibility access to read selected text from other apps.

1. Open `System Settings`
2. Go to `Privacy & Security` -> `Accessibility`
3. Enable `AnyFloat`

If permission is newly granted, quit and relaunch AnyFloat.

## Usage

1. Launch AnyFloat
2. Select text in another app
3. Press your configured global hotkey (default: `Shift + Option + F`)
4. Selected text appears in a new floating panel (you can trigger repeatedly to open multiple windows)
5. You can edit the captured text directly inside the floating panel; panel height expands/shrinks with content (within min/max limits and visible screen area)
6. If you manually resize a panel, that panel switches to manual sizing and no longer auto-adjusts height
7. If no text is selected, an empty editor opens for immediate typing; if text is captured, the panel keeps the editor unfocused on open
8. In the floating panel, use `Command + +` / `Command + -` to adjust font size
9. Use `Command + 0` to reset font size to `12`
10. Drag the panel from any non-text area around the content (top/left/right/bottom edges)
11. Close the panel with `Command + W` or the top-left close button

You can also click the AnyFloat menu bar icon and choose `Show Selected Text`.
To change the global hotkey or startup behavior, open `AnyFloat` -> `Preferences...` (or press `Command + ,`).
Both settings are saved in local `UserDefaults`.

## Troubleshooting

- Hotkey does not trigger:
  - Check for shortcut conflicts with other tools
  - Relaunch AnyFloat
- Some apps still fail:
  - Confirm Accessibility permission is granted to `AnyFloat`

## License

This project is licensed under the GNU General Public License v3.0.
See `LICENSE` for details.
