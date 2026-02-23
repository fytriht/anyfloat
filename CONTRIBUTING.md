# Contributing to AnyFloat

Thanks for contributing to AnyFloat.

## Development Environment

- macOS 13+
- Xcode Command Line Tools (`swift` available)
- Full Xcode app selected for packaging (`xcodebuild` is used by `scripts/package_app.sh`)

## Project Structure

```text
Sources/AnyFloatApp/AnyFloatApp.swift   # app entry, hotkey, AX reader, floating panel
scripts/package_app.sh                  # archive/export/signing (+ optional dmg)
Package.swift                           # SwiftPM manifest
AnyFloat.xcodeproj                      # Xcode project
```

## Build and Run

Debug build:

```bash
swift build
```

Release build:

```bash
swift build -c release
```

Run with Xcode:

1. Open `AnyFloat.xcodeproj`
2. Select the `AnyFloat` scheme
3. Press `Command + R`

## Packaging

Debug app bundle:

```bash
./scripts/package_app.sh
```

Release app bundle:

```bash
./scripts/package_app.sh --release
```

Optional DMG:

```bash
./scripts/package_app.sh [--debug|--release] --dmg
```

Default outputs are under `dist/`.

## Coding Guidelines

- Prefer minimal, targeted edits.
- Keep behavior consistent with existing hotkey / menu bar / AX extraction flow unless change is requested.
- Avoid adding dependencies unless necessary.
- Follow style used in `Sources/AnyFloatApp/AnyFloatApp.swift`:
  - clear naming
  - small focused helpers
  - explicit AX/clipboard fallbacks

## Validation Before Submitting

At minimum, run:

1. `swift build`
2. `./scripts/package_app.sh` if packaging-related files changed

If behavior changes, add/update docs accordingly.

## Documentation Sync

- Update `README.md` when user-facing behavior, setup, or usage changes.
- Update `CONTRIBUTING.md` when collaboration workflow changes.

## Pull Request Checklist

- [ ] Scope is focused and avoids unrelated refactors
- [ ] Build succeeds (`swift build`)
- [ ] Packaging verified if relevant (`./scripts/package_app.sh`)
- [ ] Documentation updated when needed

