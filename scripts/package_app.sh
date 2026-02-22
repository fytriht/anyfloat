#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="AnyFloat"
BUILD_CONFIGURATION="Debug"
APP_NAME_SUFFIX="-Debug"
SCHEME_NAME="AnyFloat"
PROJECT_PATH="$ROOT_DIR/AnyFloat.xcodeproj"
DERIVED_DATA_DIR="$ROOT_DIR/.build-xcode"
CREATE_DMG=0
PACKAGE_TIME_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
PACKAGE_UNIX_TIMESTAMP="$(date -u +"%s")"
ARCHIVE_PATH=""
APP_DIR=""
DMG_STAGING_DIR=""
DMG_PATH=""
APP_INFO_PLIST=""
SELECTED_VARIANT=""

apply_variant() {
  case "$1" in
    debug)
      BUILD_CONFIGURATION="Debug"
      APP_NAME_SUFFIX="-Debug"
      ;;
    release)
      BUILD_CONFIGURATION="Release"
      APP_NAME_SUFFIX=""
      ;;
    *)
      echo "error: unsupported build variant: $1" >&2
      print_usage >&2
      exit 1
      ;;
  esac
}

print_usage() {
  cat <<EOF
Usage: $(basename "$0") [--release|--debug] [--dmg]

Options:
  --release     Build release variant
  --debug       Build debug variant (default)
  --dmg         Also create a DMG for the selected build variant
  -h, --help    Show this help message
EOF
}

for arg in "$@"; do
  case "$arg" in
    --release)
      if [[ -n "$SELECTED_VARIANT" && "$SELECTED_VARIANT" != "release" ]]; then
        echo "error: --release and --debug cannot be used together." >&2
        print_usage >&2
        exit 1
      fi
      SELECTED_VARIANT="release"
      apply_variant release
      ;;
    --debug)
      if [[ -n "$SELECTED_VARIANT" && "$SELECTED_VARIANT" != "debug" ]]; then
        echo "error: --release and --debug cannot be used together." >&2
        print_usage >&2
        exit 1
      fi
      SELECTED_VARIANT="debug"
      apply_variant debug
      ;;
    --dmg)
      CREATE_DMG=1
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $arg" >&2
      print_usage >&2
      exit 1
      ;;
  esac
done

ARCHIVE_PATH="$DIST_DIR/${APP_NAME}${APP_NAME_SUFFIX}.xcarchive"
APP_DIR="$DIST_DIR/${APP_NAME}${APP_NAME_SUFFIX}.app"
DMG_STAGING_DIR="$DIST_DIR/${APP_NAME}${APP_NAME_SUFFIX}-dmg"
DMG_PATH="$DIST_DIR/${APP_NAME}${APP_NAME_SUFFIX}.dmg"
APP_INFO_PLIST="$APP_DIR/Contents/Info.plist"

cd "$ROOT_DIR"

# Keep build caches and temp files inside the repo to avoid permission issues.
export TMPDIR="$ROOT_DIR/.tmp"

mkdir -p "$DIST_DIR" "$TMPDIR" "$ROOT_DIR/.build/module-cache" "$ROOT_DIR/.build/module-cache-cc"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is not available. Install Xcode and select it with xcode-select." >&2
  exit 1
fi

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "error: xcodebuild is not usable with current developer directory." >&2
  echo "hint: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "error: missing project at $PROJECT_PATH" >&2
  exit 1
fi

rm -rf "$ARCHIVE_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME_NAME" \
  -configuration "$BUILD_CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  CODE_SIGNING_ALLOWED=NO \
  CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache-cc" \
  SWIFT_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"

ARCHIVED_APP_PATH="$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app"
if [[ ! -d "$ARCHIVED_APP_PATH" ]]; then
  echo "error: archive did not produce expected app at $ARCHIVED_APP_PATH" >&2
  exit 1
fi

rm -rf "$APP_DIR"
ditto "$ARCHIVED_APP_PATH" "$APP_DIR"

# Preserve packaging metadata in the final bundle Info.plist.
/usr/libexec/PlistBuddy -c "Add :AnyFloatPackageTimeUTC string $PACKAGE_TIME_UTC" "$APP_INFO_PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :AnyFloatPackageTimeUTC $PACKAGE_TIME_UTC" "$APP_INFO_PLIST"
/usr/libexec/PlistBuddy -c "Add :AnyFloatPackageTimestamp string $PACKAGE_UNIX_TIMESTAMP" "$APP_INFO_PLIST" 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :AnyFloatPackageTimestamp $PACKAGE_UNIX_TIMESTAMP" "$APP_INFO_PLIST"

# Prefer a real Apple Development identity; fallback to ad-hoc.
IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="$(security find-identity -v -p codesigning | awk -F\" '/Apple Development:/{print $2; exit}')"
fi
if [[ -z "$IDENTITY" ]]; then
  IDENTITY="-"
  echo "No Apple Development identity found, falling back to ad-hoc signing."
else
  echo "Signing with identity: $IDENTITY"
fi
codesign --force --deep --sign "$IDENTITY" "$APP_DIR"

# Clear extended attributes that can trigger policy blocks.
xattr -cr "$APP_DIR"

echo "Built ${APP_DIR}"

if [[ "$CREATE_DMG" -eq 1 ]]; then
  if ! command -v hdiutil >/dev/null 2>&1; then
    echo "error: hdiutil is not available." >&2
    exit 1
  fi

  rm -rf "$DMG_STAGING_DIR" "$DMG_PATH"
  mkdir -p "$DMG_STAGING_DIR"
  ditto "$APP_DIR" "$DMG_STAGING_DIR/${APP_NAME}${APP_NAME_SUFFIX}.app"
  ln -s /Applications "$DMG_STAGING_DIR/Applications"

  hdiutil create \
    -volname "${APP_NAME}${APP_NAME_SUFFIX}" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

  rm -rf "$DMG_STAGING_DIR"
  echo "Built ${DMG_PATH}"
else
  echo "Skipped DMG creation. Pass --dmg to build ${DMG_PATH}."
fi
