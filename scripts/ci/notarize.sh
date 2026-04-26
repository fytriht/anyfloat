#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_PATH=""
VERSION=""
SKIP_NOTARIZATION="${ANYFLOAT_SKIP_NOTARIZATION:-0}"

print_usage() {
  cat <<EOF
Usage: $(basename "$0") --app path/to/AnyFloat.app --version X.Y.Z[-beta.N|-rc.N]

Submits the app to Apple's notary service, staples the ticket, and assesses it.

Environment:
  APP_STORE_CONNECT_API_KEY_ID
  APP_STORE_CONNECT_API_ISSUER_ID
  APP_STORE_CONNECT_API_KEY_PATH
  ANYFLOAT_SKIP_NOTARIZATION=1  Skip notarization for local unsigned dry runs.
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

if [[ "$SKIP_NOTARIZATION" == "1" ]]; then
  echo "Skipping notarization because ANYFLOAT_SKIP_NOTARIZATION=1."
  exit 0
fi

: "${APP_STORE_CONNECT_API_KEY_ID:?APP_STORE_CONNECT_API_KEY_ID is required}"
: "${APP_STORE_CONNECT_API_ISSUER_ID:?APP_STORE_CONNECT_API_ISSUER_ID is required}"
: "${APP_STORE_CONNECT_API_KEY_PATH:?APP_STORE_CONNECT_API_KEY_PATH is required}"

NOTARY_ZIP="$ROOT_DIR/dist/release/AnyFloat-${VERSION}-notary.zip"
rm -f "$NOTARY_ZIP"
ditto -c -k --keepParent "$APP_PATH" "$NOTARY_ZIP"

xcrun notarytool submit "$NOTARY_ZIP" \
  --key "$APP_STORE_CONNECT_API_KEY_PATH" \
  --key-id "$APP_STORE_CONNECT_API_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_API_ISSUER_ID" \
  --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
spctl --assess --type execute --verbose=4 "$APP_PATH"

rm -f "$NOTARY_ZIP"
echo "Notarized and stapled $APP_PATH"
