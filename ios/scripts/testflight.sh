#!/usr/bin/env bash
# Archive TERRA and upload it to App Store Connect for TestFlight.
#
#   ./scripts/testflight.sh            # archive + export dist/TERRA.ipa
#   ./scripts/testflight.sh upload     # archive + upload to App Store Connect
#
# Needs: Xcode signed in to team 8D6ML34D52 (Xcode > Settings > Accounts) and an app
# record in App Store Connect with bundle ID com.zappika.terra. Signing is automatic.
# The build number is the commit count, so commit before every upload.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-export}"
[[ "$MODE" == export || "$MODE" == upload ]] || { echo "usage: $0 [export|upload]" >&2; exit 1; }
[[ -z "$(git status --porcelain .)" ]] || echo "warning: uncommitted changes — this build number may be reused by the next commit" >&2

./scripts/xcode.sh

OUT="dist"
ARCHIVE="$OUT/TERRA.xcarchive"
rm -rf "$OUT"
mkdir -p "$OUT"

xcodebuild archive \
  -project TERRA.xcodeproj -scheme TERRA -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$MODE</string>
  <key>teamID</key><string>8D6ML34D52</string>
  <key>signingStyle</key><string>automatic</string>
  <key>testFlightInternalTestingOnly</key><true/>
</dict>
</plist>
PLIST

xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  -exportPath "$OUT" \
  -allowProvisioningUpdates

if [[ "$MODE" == upload ]]; then
  echo "uploaded — it appears in App Store Connect > TestFlight after processing"
else
  echo "exported $OUT/TERRA.ipa — upload with: ./scripts/testflight.sh upload"
fi
