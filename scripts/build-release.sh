#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: ./scripts/build-release.sh <version> (e.g. 1.0.0)}"
APP_NAME="Charge Cat"
BUNDLE_ID="com.coldmans.charge-cat"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="$(uname -m)"
STAGING_DIR=$(mktemp -d)
DMG_NAME="ChargeCat-${VERSION}.dmg"
OUTPUT_DIR="${PROJECT_DIR}/dist"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"
BIN_DIR="${PROJECT_DIR}/.artifacts"
BIN_PATH="${BIN_DIR}/ChargeCat"
RESOURCE_SOURCE_DIR="${PROJECT_DIR}/Sources/ChargeCat/Resources"

echo "==> Building Charge Cat v${VERSION}..."
echo "    Project: ${PROJECT_DIR}"
echo "    Arch:    ${ARCH}"

# 1. Build release binary
cd "$PROJECT_DIR"
mkdir -p "$BIN_DIR"
swiftc -O \
  -target "${ARCH}-apple-macos14.0" \
  -o "${BIN_PATH}" \
  $(find Sources/ChargeCat -name '*.swift' | sort)

echo "==> Creating .app bundle..."

# 2. Create .app bundle structure
APP_BUNDLE="${STAGING_DIR}/${APP_NAME}.app"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# 3. Copy binary
cp "${BIN_PATH}" "${APP_BUNDLE}/Contents/MacOS/Charge Cat"
chmod +x "${APP_BUNDLE}/Contents/MacOS/Charge Cat"

# 4. Copy resources
cp -R "${RESOURCE_SOURCE_DIR}/Sounds" "${APP_BUNDLE}/Contents/Resources/"
cp -R "${RESOURCE_SOURCE_DIR}/Animations" "${APP_BUNDLE}/Contents/Resources/"
cp "${RESOURCE_SOURCE_DIR}/Assets.xcassets/AppIcon.imageset/appicon-1024.png" \
  "${APP_BUNDLE}/Contents/Resources/AppIcon.png"
cp "${RESOURCE_SOURCE_DIR}/Assets.xcassets/MenuBarIcon.imageset/menubar-36.png" \
  "${APP_BUNDLE}/Contents/Resources/MenuBarIcon.png"
echo "    Copied sounds, animations, and icons"

# 5. Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Charge Cat</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
</dict>
</plist>
PLIST

# 6. Create PkgInfo
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "==> Creating DMG..."

# 7. Create DMG with Applications symlink
mkdir -p "$OUTPUT_DIR"
DMG_STAGING="${STAGING_DIR}/dmg-content"
mkdir -p "${DMG_STAGING}"
cp -R "${APP_BUNDLE}" "${DMG_STAGING}/"
ln -s /Applications "${DMG_STAGING}/Applications"

hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${DMG_STAGING}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}"

# 8. Calculate sha256
SHA=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')
SIZE=$(du -h "${DMG_PATH}" | awk '{print $1}')

echo ""
echo "============================================"
echo "  Build complete!"
echo "============================================"
echo "  DMG:     ${DMG_PATH}"
echo "  SHA256:  ${SHA}"
echo "  Size:    ${SIZE}"
echo "  Arch:    $(uname -m)"
echo ""
echo "  Next steps:"
echo "  1. gh release create v${VERSION} '${DMG_PATH}' --title 'v${VERSION}' --notes 'Charge Cat v${VERSION}'"
echo "  2. Update Casks/charge-cat.rb with sha256 \"${SHA}\""
echo ""

# Cleanup
rm -rf "${STAGING_DIR}"
