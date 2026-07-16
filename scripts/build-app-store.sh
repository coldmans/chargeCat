#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: ./scripts/build-app-store.sh <version> <build-number>"
  echo "Example: ./scripts/build-app-store.sh 1.0.0 1"
  exit 64
fi

VERSION="$1"
BUILD_NUMBER="$2"
TEAM_ID="${DEVELOPMENT_TEAM:-2CAPC352DD}"
BUNDLE_ID="${PRODUCT_BUNDLE_IDENTIFIER:-com.coldmans.charge-cat}"
EXPORT_APP_STORE="${EXPORT_APP_STORE:-1}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-1}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${PROJECT_DIR}/dist/app-store"
ARTIFACT_NAME="ChargeCat-${VERSION}-${BUILD_NUMBER}"
ARCHIVE_PATH="${OUTPUT_DIR}/${ARTIFACT_NAME}.xcarchive"
EXPORT_PATH="${OUTPUT_DIR}/${ARTIFACT_NAME}"
EXPORT_OPTIONS="$(mktemp)"
ENTITLEMENTS_OUTPUT="$(mktemp)"

cleanup() {
  rm -f "$EXPORT_OPTIONS" "$ENTITLEMENTS_OUTPUT"
}
trap cleanup EXIT

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
  echo "Version must look like 1.0 or 1.0.0."
  exit 64
fi

if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
  echo "Build number must be a positive integer."
  exit 64
fi

if [[ "$EXPORT_APP_STORE" != "0" && "$EXPORT_APP_STORE" != "1" ]]; then
  echo "EXPORT_APP_STORE must be 0 or 1."
  exit 64
fi

if [[ "$ALLOW_PROVISIONING_UPDATES" != "0" && "$ALLOW_PROVISIONING_UPDATES" != "1" ]]; then
  echo "ALLOW_PROVISIONING_UPDATES must be 0 or 1."
  exit 64
fi

for command_name in xcodebuild codesign lipo pkgutil plutil; do
  if ! command -v "$command_name" >/dev/null; then
    echo "Missing required command: ${command_name}"
    exit 69
  fi
done

if [[ -e "$EXPORT_PATH" ]]; then
  echo "Export output already exists for ${VERSION} (${BUILD_NUMBER}). Use a new build number or move the existing artifact."
  exit 73
fi

mkdir -p "$OUTPUT_DIR"
cp "${PROJECT_DIR}/Config/AppStoreExportOptions.plist" "$EXPORT_OPTIONS"
plutil -replace teamID -string "$TEAM_ID" "$EXPORT_OPTIONS"

archive_app() {
  xcodebuild \
    -project "${PROJECT_DIR}/ChargeCat.xcodeproj" \
    -scheme ChargeCat \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    "$@" \
    archive
}

if [[ -d "$ARCHIVE_PATH" ]]; then
  echo "==> Reusing existing archive"
  echo "    ${ARCHIVE_PATH}"
else
  echo "==> Archiving Charge Cat ${VERSION} (${BUILD_NUMBER})"
  echo "    Team:      ${TEAM_ID}"
  echo "    Bundle ID: ${BUNDLE_ID}"

  if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
    archive_app -allowProvisioningUpdates
  else
    archive_app
  fi
fi

APP_PATH="${ARCHIVE_PATH}/Products/Applications/Charge Cat.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Archive does not contain Charge Cat.app."
  exit 70
fi

codesign --verify --deep --strict "$APP_PATH"
codesign -d --entitlements :- "$APP_PATH" >"$ENTITLEMENTS_OUTPUT" 2>/dev/null

SANDBOX_ENABLED="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$ENTITLEMENTS_OUTPUT" 2>/dev/null || true)"
if [[ "$SANDBOX_ENABLED" != "true" ]]; then
  echo "Archived app is missing the App Sandbox entitlement."
  exit 70
fi

if grep -a -q "/usr/bin/pmset" "${APP_PATH}/Contents/MacOS/Charge Cat"; then
  echo "Archived app still contains the sandbox-incompatible pmset path."
  exit 70
fi

ARCHITECTURES="$(lipo -archs "${APP_PATH}/Contents/MacOS/Charge Cat")"
if [[ "$ARCHITECTURES" != *"arm64"* || "$ARCHITECTURES" != *"x86_64"* ]]; then
  echo "Archived app must contain both arm64 and x86_64 architectures."
  exit 70
fi

PRIVACY_MANIFEST="${APP_PATH}/Contents/Resources/PrivacyInfo.xcprivacy"
if [[ ! -f "$PRIVACY_MANIFEST" ]]; then
  echo "Archived app is missing PrivacyInfo.xcprivacy."
  exit 70
fi
plutil -lint "$PRIVACY_MANIFEST" >/dev/null

if [[ "$EXPORT_APP_STORE" == "0" ]]; then
  echo "==> Archive complete"
  echo "    ${ARCHIVE_PATH}"
  exit 0
fi

echo "==> Exporting App Store Connect package"
export_archive() {
  xcodebuild \
    -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    "$@"
}

if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
  export_archive -allowProvisioningUpdates
else
  export_archive
fi

PKG_PATH="$(find "$EXPORT_PATH" -maxdepth 1 -type f -name '*.pkg' -print -quit)"
if [[ -z "$PKG_PATH" ]]; then
  echo "Export finished without producing a .pkg file."
  exit 70
fi
pkgutil --check-signature "$PKG_PATH" >/dev/null

echo "==> App Store package complete"
echo "    Archive: ${ARCHIVE_PATH}"
echo "    Package: ${PKG_PATH}"
echo "    Upload the package with Xcode Organizer, Transporter, or altool."
