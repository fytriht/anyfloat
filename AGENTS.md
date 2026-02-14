# AGENTS.md

This file defines repository-specific instructions for coding agents working in `TextF`.

## Project Summary
- App type: native macOS menu bar app (SwiftPM).
- Main entry: `Sources/TextFApp/main.swift`.
- Package manifest: `Package.swift`.
- Packaging script: `scripts/package_app.sh`.

## Environment
- Required: macOS 13+, Xcode Command Line Tools (`swift` available).
- Keep cache/temp artifacts inside repo when possible (see `scripts/package_app.sh`).

## Build, Run, Verify
- Debug build: `swift build`
- Release build: `swift build -c release`
- Run release binary: `./.build/release/TextFApp`
- Package app bundle: `./scripts/package_app.sh`

Before finishing code changes, agents should run at least:
1. `swift build`
2. If packaging-related files changed: `./scripts/package_app.sh`

## Coding Guidelines
- Prefer minimal, targeted edits.
- Keep behavior consistent with existing hotkey / menu bar / AX text extraction flow unless change is requested.
- Avoid introducing new dependencies unless necessary.
- Follow existing Swift style in `main.swift`:
  - clear naming
  - small focused helpers
  - explicit fallbacks for AX/clipboard behavior

## Safety Rules
- Do not use destructive git commands (for example `git reset --hard`) unless explicitly requested.
- Do not revert unrelated local changes.
- Do not modify signing identity logic in packaging unless required by task.

## Documentation Sync
- Update `README.md` whenever code changes affect features, setup, build/run commands, configuration, or known limitations.
- Update `AGENTS.md` whenever repository workflow or agent collaboration rules change.
- Before finishing a task, verify docs are in sync; if documentation-impacting behavior changed, doc updates are required.

## Change Notes
When making non-trivial changes, include:
- What changed
- Why it changed
- How it was validated (commands run)
