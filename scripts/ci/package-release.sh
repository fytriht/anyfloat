#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_PATH=""
VERSION=""
APP_NAME="AnyFloat"
DIST_DIR="$ROOT_DIR/dist/release"

print_usage() {
  cat <<EOF
Usage: $(basename "$0") --app path/to/AnyFloat.app --version X.Y.Z

Creates release ZIP, DMG, and SHA-256 checksum artifacts under dist/release.
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

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: app bundle not found at $APP_PATH" >&2
  exit 1
fi

if [[ ! "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+$ ]]; then
  echo "error: --version must match X.Y.Z" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"

ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
DMG_STAGING_DIR="$DIST_DIR/${APP_NAME}-${VERSION}-dmg"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
CHECKSUM_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.sha256"

rm -rf "$ZIP_PATH" "$DMG_STAGING_DIR" "$DMG_PATH" "$CHECKSUM_PATH"

ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

mkdir -p "$DMG_STAGING_DIR"
ditto "$APP_PATH" "$DMG_STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

hdiutil create \
  -volname "${APP_NAME} ${VERSION}" \
  -srcfolder "$DMG_STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DMG_STAGING_DIR"

(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$DMG_PATH")" "$(basename "$ZIP_PATH")" > "$CHECKSUM_PATH"
)

echo "Built $DMG_PATH"
echo "Built $ZIP_PATH"
echo "Built $CHECKSUM_PATH"
