# Contributing to AnyFloat

Thanks for contributing to AnyFloat.

## Development Environment

- macOS 13+
- Full Xcode app selected for `xcodebuild` (used for local builds and release packaging)

## Project Structure

```text
Sources/AnyFloatApp/AnyFloatApp.swift   # app entry, hotkey, AX reader, floating panel
scripts/ci/                             # release build, notarization, packaging, verification helpers
.github/workflows/release.yml           # tag-driven GitHub Releases workflow
AnyFloat.xcodeproj                      # Xcode project
```

## Build and Run

Debug build:

```bash
xcodebuild -project AnyFloat.xcodeproj -scheme AnyFloat -configuration Debug -derivedDataPath .build-xcode build CODE_SIGNING_ALLOWED=NO
```

Release build:

```bash
xcodebuild -project AnyFloat.xcodeproj -scheme AnyFloat -configuration Release -derivedDataPath .build-xcode build CODE_SIGNING_ALLOWED=NO
```

Run built binary:

```bash
# Debug
./.build-xcode/Build/Products/Debug/AnyFloat.app/Contents/MacOS/AnyFloat

# Release
./.build-xcode/Build/Products/Release/AnyFloat.app/Contents/MacOS/AnyFloat
```

Run with Xcode:

1. Open `AnyFloat.xcodeproj`
2. Select the `AnyFloat` scheme
3. Press `Command + R`

## Release Packaging

Release artifacts are built by GitHub Actions from tags. The release source of truth is the Git tag:

```bash
git tag v1.2.3
git push origin v1.2.3
```

Prerelease tags are also supported:

```bash
git tag v1.2.3-beta.1
git push origin v1.2.3-beta.1
```

Supported release tag formats are `vX.Y.Z`, `vX.Y.Z-beta.N`, and `vX.Y.Z-rc.N`. Pushing one of these tags runs `.github/workflows/release.yml`, which:

- builds the Release archive with `MARKETING_VERSION=X.Y.Z`
- sets `CURRENT_PROJECT_VERSION` to the GitHub Actions run number
- signs the app with Developer ID
- notarizes and staples the app
- uploads `AnyFloat-<release-version>.dmg`, `AnyFloat-<release-version>.zip`, and checksums to GitHub Releases

For prerelease tags, GitHub Releases are marked as prereleases. The app bundle still uses the base `MARKETING_VERSION` (`1.2.3` for `v1.2.3-beta.1`) because macOS bundle short versions must stay numeric.

Manual workflow dispatch can build the same artifacts without publishing a GitHub Release when `publish` is false.

Repository secrets required for signed releases:

- `APPLE_DEVELOPER_ID_CERTIFICATE_BASE64`
- `APPLE_DEVELOPER_ID_CERTIFICATE_PASSWORD`
- `APPLE_KEYCHAIN_PASSWORD`
- `APPLE_TEAM_ID`
- `APP_STORE_CONNECT_API_KEY_ID`
- `APP_STORE_CONNECT_API_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_P8`

Local unsigned release helper smoke test:

```bash
ANYFLOAT_SKIP_SIGNING=1 scripts/ci/build-release.sh --version 0.0.0 --build-number 1
ANYFLOAT_SKIP_SIGNING=1 ANYFLOAT_SKIP_NOTARIZATION=1 scripts/ci/verify-release.sh --app dist/release/AnyFloat.app --version 0.0.0 --build-number 1
ANYFLOAT_SKIP_SIGNING=1 scripts/ci/package-release.sh --app dist/release/AnyFloat.app --version 0.0.0
```

Release helper outputs are under `dist/release/`.

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

1. `xcodebuild -project AnyFloat.xcodeproj -scheme AnyFloat -configuration Debug -derivedDataPath .build-xcode build CODE_SIGNING_ALLOWED=NO`
2. The local unsigned release helper smoke test if release workflow or packaging helpers changed

If behavior changes, add/update docs accordingly.

## Documentation Sync

- Update `README.md` when user-facing behavior, setup, or usage changes.
- Update `CONTRIBUTING.md` when collaboration workflow changes.

## Branching and Merge Policy

- `main` is the trunk branch for development.
- All commits should be merged into `main` through pull requests.
- Direct push to `main` is not allowed.

## Pull Request Checklist

- [ ] Scope is focused and avoids unrelated refactors
- [ ] Build succeeds (`xcodebuild -project AnyFloat.xcodeproj -scheme AnyFloat -configuration Debug -derivedDataPath .build-xcode build CODE_SIGNING_ALLOWED=NO`)
- [ ] Release helper smoke test completed if relevant
- [ ] Documentation updated when needed
