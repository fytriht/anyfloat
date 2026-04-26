#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_PATH=""
VERSION=""
APP_NAME="AnyFloat"
DIST_DIR="$ROOT_DIR/dist/release"
SKIP_SIGNING="${ANYFLOAT_SKIP_SIGNING:-0}"

print_usage() {
  cat <<EOF
Usage: $(basename "$0") --app path/to/AnyFloat.app --version X.Y.Z[-beta.N|-rc.N]

Creates release ZIP, DMG, and SHA-256 checksum artifacts under dist/release.

Environment:
  ANYFLOAT_SKIP_SIGNING=1  Skip ZIP codesign verification for local unsigned dry runs.
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

if [[ ! "$VERSION" =~ ^[0-9]+[.][0-9]+[.][0-9]+(-(beta|rc)[.][0-9]+)?$ ]]; then
  echo "error: --version must match X.Y.Z, X.Y.Z-beta.N, or X.Y.Z-rc.N" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"

ZIP_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.zip"
DMG_STAGING_DIR="$DIST_DIR/${APP_NAME}-${VERSION}-dmg"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
CHECKSUM_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.sha256"
ZIP_VERIFY_DIR="$DIST_DIR/${APP_NAME}-${VERSION}-zip-verify"

rm -rf "$ZIP_PATH" "$DMG_STAGING_DIR" "$DMG_PATH" "$CHECKSUM_PATH" "$ZIP_VERIFY_DIR"

ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$ZIP_PATH"
if [[ "$SKIP_SIGNING" == "1" ]]; then
  echo "Skipping ZIP codesign verification because ANYFLOAT_SKIP_SIGNING=1."
else
  mkdir -p "$ZIP_VERIFY_DIR"
  ditto -x -k "$ZIP_PATH" "$ZIP_VERIFY_DIR"
  codesign --verify --deep --strict --verbose=4 "$ZIP_VERIFY_DIR/${APP_NAME}.app"
  rm -rf "$ZIP_VERIFY_DIR"
fi

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
