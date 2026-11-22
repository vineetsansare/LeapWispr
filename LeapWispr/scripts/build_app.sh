#!/usr/bin/env bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRATCH_DIR="/tmp/leapwispr_build"
APP_DIR="${PROJECT_DIR}/build/LeapWispr.app"
DEST_APP="/Applications/LeapWispr.app"

echo "🛑 Stopping any existing LeapWispr processes..."
killall -9 LeapWispr 2>/dev/null || true
sleep 1

echo "🔨 Building LeapWispr Release Binary..."
cd "${PROJECT_DIR}"
swift build -c release --scratch-path "${SCRATCH_DIR}"

echo "📦 Assembling LeapWispr.app bundle..."
rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"

cp "${SCRATCH_DIR}/out/Products/Release/LeapWispr" "${APP_DIR}/Contents/MacOS/LeapWispr"
chmod +x "${APP_DIR}/Contents/MacOS/LeapWispr"
cp "${PROJECT_DIR}/Resources/Info.plist" "${APP_DIR}/Contents/Info.plist"

echo "✍️ Signing application bundle..."
codesign --force --deep -s - -r='designated => identifier "com.leapwispr.app"' "${APP_DIR}"

echo "🚀 Installing to ${DEST_APP}..."
rm -rf "${DEST_APP}"
cp -R "${APP_DIR}" "${DEST_APP}"
codesign --force --deep -s - -r='designated => identifier "com.leapwispr.app"' "${DEST_APP}"

echo "✅ LeapWispr.app successfully installed at: ${DEST_APP}"
ls -lh "${DEST_APP}/Contents/MacOS/LeapWispr"
