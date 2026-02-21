#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="AnyFloat"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
PACKAGE_TIME_UTC="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
PACKAGE_UNIX_TIMESTAMP="$(date -u +"%s")"

cd "$ROOT_DIR"

# Keep build caches inside the repo to avoid permission issues.
export XDG_CACHE_HOME="$ROOT_DIR/.cache"
export SWIFTPM_CONFIG_DIR="$ROOT_DIR/.swiftpm/config"
export SWIFTPM_SECURITY_DIR="$ROOT_DIR/.swiftpm/security"
export SWIFTPM_CACHE_DIR="$ROOT_DIR/.swiftpm/cache"
export TMPDIR="$ROOT_DIR/.tmp"

mkdir -p "$XDG_CACHE_HOME" "$SWIFTPM_CONFIG_DIR" "$SWIFTPM_SECURITY_DIR" "$SWIFTPM_CACHE_DIR" "$TMPDIR"

swift build -c release \
  -Xswiftc -module-cache-path -Xswiftc "$ROOT_DIR/.build/module-cache" \
  -Xcc -fmodules-cache-path="$ROOT_DIR/.build/module-cache-cc"

rm -rf "$APP_DIR"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/release/${APP_NAME}" "$MACOS_DIR/${APP_NAME}"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>AnyFloat</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>AnyFloat</string>
    <key>CFBundleIdentifier</key>
    <string>com.anyfloat.app</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleSignature</key>
    <string>ANYF</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>AnyFloatPackageTimeUTC</key>
    <string>${PACKAGE_TIME_UTC}</string>
    <key>AnyFloatPackageTimestamp</key>
    <string>${PACKAGE_UNIX_TIMESTAMP}</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# Ensure executable bit
chmod +x "$MACOS_DIR/${APP_NAME}"

# Legacy PkgInfo (some tools still expect it).
echo "APPLANYF" > "$CONTENTS_DIR/PkgInfo"

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
