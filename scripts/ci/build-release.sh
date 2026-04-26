#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_PATH="$ROOT_DIR/AnyFloat.xcodeproj"
SCHEME_NAME="AnyFloat"
APP_NAME="AnyFloat"
DERIVED_DATA_DIR="$ROOT_DIR/.build-xcode"
DIST_DIR="$ROOT_DIR/dist/release"
ARCHIVE_PATH="$DIST_DIR/${APP_NAME}.xcarchive"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
VERSION=""
BUILD_NUMBER=""
SKIP_SIGNING="${ANYFLOAT_SKIP_SIGNING:-0}"

print_usage() {
  cat <<EOF
Usage: $(basename "$0") --version X.Y.Z --build-number N

Builds the Release archive into dist/release.

Environment:
  ANYFLOAT_SKIP_SIGNING=1  Build locally without code signing.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
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

if [[ ! "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
  echo "error: --version must match X.Y.Z" >&2
  exit 1
fi

if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "error: --build-number must be a positive integer" >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "error: xcodebuild is not available. Install Xcode and select it with xcode-select." >&2
  exit 1
fi

mkdir -p \
  "$DIST_DIR" \
  "$ROOT_DIR/.build/module-cache" \
  "$ROOT_DIR/.build/module-cache-cc" \
  "$ROOT_DIR/.cache" \
  "$ROOT_DIR/.home" \
  "$ROOT_DIR/.tmp"
rm -rf "$ARCHIVE_PATH" "$APP_DIR"

XCODEBUILD_ARGS=(
  -project "$PROJECT_PATH"
  -scheme "$SCHEME_NAME"
  -configuration Release
  -derivedDataPath "$DERIVED_DATA_DIR"
  -archivePath "$ARCHIVE_PATH"
  archive
  MARKETING_VERSION="$VERSION"
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
  CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache-cc"
  SWIFT_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
)

if [[ "$SKIP_SIGNING" == "1" ]]; then
  XCODEBUILD_ARGS+=(CODE_SIGNING_ALLOWED=NO)
else
  XCODEBUILD_ARGS+=(
    CODE_SIGNING_ALLOWED=YES
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application}"
    DEVELOPMENT_TEAM="${APPLE_TEAM_ID:?APPLE_TEAM_ID is required for signed release builds}"
    OTHER_CODE_SIGN_FLAGS="--timestamp"
  )
fi

cd "$ROOT_DIR"
HOME="$ROOT_DIR/.home" \
TMPDIR="$ROOT_DIR/.tmp" \
XDG_CACHE_HOME="$ROOT_DIR/.cache" \
xcodebuild "${XCODEBUILD_ARGS[@]}"

ARCHIVED_APP_PATH="$ARCHIVE_PATH/Products/Applications/${APP_NAME}.app"
if [[ ! -d "$ARCHIVED_APP_PATH" ]]; then
  echo "error: archive did not produce expected app at $ARCHIVED_APP_PATH" >&2
  exit 1
fi

ditto "$ARCHIVED_APP_PATH" "$APP_DIR"
echo "Built $APP_DIR"
