# AGENTS.md

This file defines repository-specific instructions for coding agents working in `AnyFloat`.

## Project Summary
- App type: native macOS menu bar app (Xcode project).
- Main entry: `Sources/AnyFloatApp/AnyFloatApp.swift`.
  - `AnyFloatApp`: SwiftUI entry; forwards About / Preferences commands to `AppDelegate`.
  - `AppDelegate`: app lifecycle, status bar menu, global hotkey, accessibility prompt, launch-at-login.
  - Hotkey + preferences (`HotKeyConfiguration`, `HotKeyRecorderView`, `PreferencesWindowController`): shortcut validation/persistence and Preferences UI.
  - Floating panel (`FloatingPanelController`, `FloatingBorderlessPanel`, `FloatingTextView`): floating window creation, positioning, and text sizing behavior.
  - AX text reader (`SelectedTextReader`): gets selected text from the frontmost external app.
  - Analytics (`AnalyticsManager`): Mixpanel setup and core event tracking.
- Xcode project: `AnyFloat.xcodeproj`.
- Release workflow: `.github/workflows/release.yml`.
- CI release helpers: `scripts/ci/`.

## Docs Navigation
- When needed, review documentation under `docs/` for project terminology or behavior context.
- `docs/glossary.md`: concise project terminology reference.

## Environment
- Required: macOS 13+.
- Required for build and release packaging: full Xcode app selected for `xcodebuild`.
- Keep cache/temp artifacts inside repo when possible.

## Build, Run, Verify
- Debug build: `xcodebuild -project AnyFloat.xcodeproj -scheme AnyFloat -configuration Debug -derivedDataPath .build-xcode build CODE_SIGNING_ALLOWED=NO`
- Release build: `xcodebuild -project AnyFloat.xcodeproj -scheme AnyFloat -configuration Release -derivedDataPath .build-xcode build CODE_SIGNING_ALLOWED=NO`
- Run built binary:
  - Debug: `./.build-xcode/Build/Products/Debug/AnyFloat.app/Contents/MacOS/AnyFloat`
  - Release: `./.build-xcode/Build/Products/Release/AnyFloat.app/Contents/MacOS/AnyFloat`
- Local unsigned release helper smoke test: `ANYFLOAT_SKIP_SIGNING=1 scripts/ci/build-release.sh --version 0.0.0 --build-number 1`
- Package local release artifact after a helper build: `scripts/ci/package-release.sh --app dist/release/AnyFloat.app --version 0.0.0`

Before finishing changes, run verification only when relevant:
1. If app code, project config, or build scripts changed, run: `xcodebuild -project AnyFloat.xcodeproj -scheme AnyFloat -configuration Debug -derivedDataPath .build-xcode build CODE_SIGNING_ALLOWED=NO`
2. If release workflow or CI packaging helpers changed, run the local unsigned release helper smoke test when feasible:
   - `ANYFLOAT_SKIP_SIGNING=1 scripts/ci/build-release.sh --version 0.0.0 --build-number 1`
   - `ANYFLOAT_SKIP_SIGNING=1 ANYFLOAT_SKIP_NOTARIZATION=1 scripts/ci/verify-release.sh --app dist/release/AnyFloat.app --version 0.0.0 --build-number 1`
   - `scripts/ci/package-release.sh --app dist/release/AnyFloat.app --version 0.0.0`
3. If only documentation/non-executable files changed (for example, `.md`), build verification can be skipped.

## Coding Guidelines
- Prefer minimal, targeted edits.
- Clean up unused code promptly when making changes to avoid leaving dead code behind.
- Keep behavior consistent with existing hotkey / menu bar / AX text extraction flow unless change is requested.
- Avoid introducing new dependencies unless necessary.
- Do not add new analytics tracking events unless explicitly requested.

## Safety Rules
- Do not use destructive git commands (for example `git reset --hard`) unless explicitly requested.
- Do not revert unrelated local changes.

## Documentation Sync
- When needed, consult docs in `docs/` before making assumptions about project terms or documented behavior.
- Update `AGENTS.md` whenever repository workflow or agent collaboration rules change.
- Before finishing a task, verify docs are in sync; if terminology, behavior, usage, or workflow changed, update the relevant docs.
- When editing code or behavior that is already documented, keep the corresponding docs updated in the same change when applicable.

## Test Case Reference
- When needed, agents may reference `.note/test-cases.md` for test case details.
- Do not edit `.note/test-cases.md`.
- If `.note/test-cases.md` is missing, inform the user to pull/sync that repository manually.

## Change Notes
When making non-trivial changes, include:
- What changed
- Why it changed
- How it was validated (commands run)
