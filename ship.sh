#!/bin/bash
# MathPilot - archive & upload to App Store Connect
# Prerequisites:
#   1. Paid Apple Developer Program membership ($99/yr)
#   2. Xcode > Settings > Accounts: signed in with the Apple ID
#   3. App Store Connect: app created with bundle ID com.mathpilot.app
# Usage: ./ship.sh
set -euo pipefail

cd "$(dirname "$0")"

ARCHIVE_PATH="./build/MathPilot.xcarchive"
LOG_DIR="./build/logs"
mkdir -p "$LOG_DIR"

echo "==> Archiving MathPilot (Release)..."
xcodebuild archive \
  -project MathPilot.xcodeproj \
  -scheme MathPilot \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  2>&1 | tee "$LOG_DIR/archive.log" | tail -5

echo "==> Exporting & uploading to App Store Connect..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates \
  2>&1 | tee "$LOG_DIR/export.log" | tail -10

echo "==> Done. Build will appear in App Store Connect > TestFlight"
echo "    after processing (~5-30 min). Then attach it to your 1.0"
echo "    version and Submit for Review."
