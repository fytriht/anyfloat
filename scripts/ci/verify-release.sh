#!/usr/bin/env bash
set -euo pipefail

APP_PATH=""
VERSION=""
BUILD_NUMBER=""
SKIP_NOTARIZATION="${ANYFLOAT_SKIP_NOTARIZATION:-0}"
SKIP_SIGNING="${ANYFLOAT_SKIP_SIGNING:-0}"

print_usage() {
  cat <<EOF
Usage: $(basename "$0") --app path/to/AnyFloat.app --version X.Y.Z --build-number N

Verifies bundle versions, code signature, and notarization assessment.

Environment:
  ANYFLOAT_SKIP_SIGNING=1       Skip codesign verification for local unsigned dry runs.
  ANYFLOAT_SKIP_NOTARIZATION=1  Skip Gatekeeper assessment for local dry runs.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_PATH="${2:-}"
      shift 2
      ;;
    --version)
      VERSION="${2:-}"
      shift 2
      ;;
    --build-number)
      BUILD_NUMBER="${2:-}"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      print_usage >&2
      exit 1
      ;;
  esac
done

INFO_PLIST="$APP_PATH/Contents/Info.plist"

if [[ ! -f "$INFO_PLIST" ]]; then
  echo "error: Info.plist not found at $INFO_PLIST" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
  echo "error: --version must match X.Y.Z" >&2
  exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "error: --build-number must be a positive integer" >&2
  exit 1
fi

actual_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
actual_build="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"

if [[ "$actual_version" != "$VERSION" ]]; then
  echo "error: expected CFBundleShortVersionString=$VERSION, got $actual_version" >&2
  exit 1
fi

if [[ "$actual_build" != "$BUILD_NUMBER" ]]; then
  echo "error: expected CFBundleVersion=$BUILD_NUMBER, got $actual_build" >&2
  exit 1
fi

if [[ "$SKIP_SIGNING" == "1" ]]; then
  echo "Skipping codesign verification because ANYFLOAT_SKIP_SIGNING=1."
else
  codesign --verify --deep --strict --verbose=4 "$APP_PATH"
fi

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "Skipping Gatekeeper assessment because ANYFLOAT_SKIP_NOTARIZATION=1."
else
  spctl --assess --type execute --verbose=4 "$APP_PATH"
fi

echo "Verified $APP_PATH"
