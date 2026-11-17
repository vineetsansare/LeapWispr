#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${PROJECT_DIR}/build/LeapWispr.app"
DMG_STAGING="/tmp/leapwispr_dmg_staging"
OUTPUT_DMG="${PROJECT_DIR}/build/LeapWispr.dmg"

# First, build the app bundle
"${PROJECT_DIR}/scripts/build_app.sh"

echo "💿 Packaging LeapWispr into DMG..."
rm -rf "${DMG_STAGING}" "${OUTPUT_DMG}"
mkdir -p "${DMG_STAGING}"

# Copy LeapWispr.app to staging
cp -R "${APP_DIR}" "${DMG_STAGING}/LeapWispr.app"

# Create symlink to /Applications for easy drag-and-drop installation
ln -s /Applications "${DMG_STAGING}/Applications"

# Create the compressed DMG
hdiutil create \
    -volname "LeapWispr" \
    -srcfolder "${DMG_STAGING}" \
    -ov \
    -format UDZO \
    "${OUTPUT_DMG}"

rm -rf "${DMG_STAGING}"

echo "🎉 Done! Shareable DMG created at:"
ls -lh "${OUTPUT_DMG}"
