#!/bin/bash
# MathPilot - archive & upload to App Store Connect
# Prerequisites:
#   1. Paid Apple Developer Program membership ($99/yr)
#   2. Readable App Store Connect API key (configured in ExportOptions.plist)
#   3. App Store Connect: app created with bundle ID com.mathpilot.app
# Usage: ./ship.sh (uploads); BUILD_NUMBER=3 ./ship.sh overrides the project build number
set -euo pipefail

cd "$(dirname "$0")"

ARCHIVE_PATH="./build/MathPilot.xcarchive"
LOG_DIR="./build/logs"

# xcodebuild requires authentication as command-line flags, not export plist keys.
ASC_KEY_ID="${ASC_KEY_ID:-$(/usr/libexec/PlistBuddy -c 'Print authenticationKeyID' ExportOptions.plist)}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-$(/usr/libexec/PlistBuddy -c 'Print authenticationKeyIssuerID' ExportOptions.plist)}"
ASC_KEY_PATH="${ASC_KEY_PATH:-$(/usr/libexec/PlistBuddy -c 'Print authenticationKeyPath' ExportOptions.plist)}"
if [[ ! -r "$ASC_KEY_PATH" ]]; then
  echo "App Store Connect key is not readable: $ASC_KEY_PATH" >&2
  exit 1
fi
AUTH_ARGS=(-allowProvisioningUpdates -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID" -authenticationKeyPath "$ASC_KEY_PATH")
BUILD_ARGS=(-configuration Release)
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  BUILD_ARGS+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")
fi
mkdir -p "$LOG_DIR"

echo "==> Archiving MathPilot (Release)..."
xcodebuild archive \
  -project MathPilot.xcodeproj \
  -scheme MathPilot \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  "${AUTH_ARGS[@]}" "${BUILD_ARGS[@]}" \
  2>&1 | tee "$LOG_DIR/archive.log" | tail -5

echo "==> Exporting & uploading to App Store Connect..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist ExportOptions.plist \
  "${AUTH_ARGS[@]}" \
  2>&1 | tee "$LOG_DIR/export.log" | tail -10

echo "==> Done. Build will appear in App Store Connect > TestFlight"
echo "    after processing (~5-30 min). Then attach it to your 1.0"
echo "    version and Submit for Review."
