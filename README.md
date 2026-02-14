# TextF

Native macOS app. Select text anywhere, press the global hotkey, and the selected text shows in a floating, draggable, closable window.

## Build

```bash
cd /Users/zhi/Developer/TextF
swift build -c release
```

## Run (binary)

```bash
cd /Users/zhi/Developer/TextF
./.build/release/TextFApp
```

## Build `.app` bundle

```bash
cd /Users/zhi/Developer/TextF
./scripts/package_app.sh
```

The app bundle will be created at:

```
dist/TextFApp.app
```

## First launch permissions

The app needs Accessibility permission to read selected text.

Open:

- System Settings
- Privacy & Security
- Accessibility
- Enable `TextFApp`
