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
- Packaging script: `scripts/package_app.sh`.

## Environment
- Required: macOS 13+.
- Required for build and packaging: full Xcode app selected for `xcodebuild`.
- Keep cache/temp artifacts inside repo when possible (see `scripts/package_app.sh`).

## Build, Run, Verify
- Debug build: `xcodebuild -project AnyFloat.xcodeproj -scheme AnyFloat -configuration Debug -derivedDataPath .build-xcode build CODE_SIGNING_ALLOWED=NO`
- Release build: `xcodebuild -project AnyFloat.xcodeproj -scheme AnyFloat -configuration Release -derivedDataPath .build-xcode build CODE_SIGNING_ALLOWED=NO`
- Run built binary:
  - Debug: `./.build-xcode/Build/Products/Debug/AnyFloat.app/Contents/MacOS/AnyFloat`
  - Release: `./.build-xcode/Build/Products/Release/AnyFloat.app/Contents/MacOS/AnyFloat`
- Package app bundle: `./scripts/package_app.sh`

Before finishing changes, run verification only when relevant:
1. If app code, project config, or build scripts changed, run: `xcodebuild -project AnyFloat.xcodeproj -scheme AnyFloat -configuration Debug -derivedDataPath .build-xcode build CODE_SIGNING_ALLOWED=NO`
2. If packaging-related files changed, run: `./scripts/package_app.sh`
3. If only documentation/non-executable files changed (for example, `.md`), build verification can be skipped.

## Coding Guidelines
- Prefer minimal, targeted edits.
- Keep behavior consistent with existing hotkey / menu bar / AX text extraction flow unless change is requested.
- Avoid introducing new dependencies unless necessary.
- Do not add new analytics tracking events unless explicitly requested.

## Safety Rules
- Do not use destructive git commands (for example `git reset --hard`) unless explicitly requested.
- Do not revert unrelated local changes.

## Documentation Sync
- Update `AGENTS.md` whenever repository workflow or agent collaboration rules change.
- Before finishing a task, verify docs are in sync; if documentation-impacting behavior changed, doc updates are required.

## Test Case Reference
- When needed, agents may reference `.note/test-cases.md` for test case details.
- Do not edit `.note/test-cases.md`.
- If `.note/test-cases.md` is missing, inform the user to pull/sync that repository manually.

## Change Notes
When making non-trivial changes, include:
- What changed
- Why it changed
- How it was validated (commands run)
