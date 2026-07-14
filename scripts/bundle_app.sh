#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/SwiftType.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "==> Building SwiftType release binary..."
if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi
swift build -c release --arch arm64

echo "==> Creating macOS Application Bundle structure..."
rm -rf "${APP_DIR}" "${BUILD_DIR}/SwiftType.zip"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

echo "==> Copying binary into application bundle..."
if [ -f ".build/arm64-apple-macosx/release/SwiftType" ]; then
    cp ".build/arm64-apple-macosx/release/SwiftType" "${MACOS_DIR}/SwiftType"
else
    cp ".build/release/SwiftType" "${MACOS_DIR}/SwiftType"
fi
chmod +x "${MACOS_DIR}/SwiftType"

echo "==> Writing PkgInfo..."
echo -n "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "==> Generating Info.plist..."
cat <<EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>SwiftType</string>
	<key>CFBundleIdentifier</key>
	<string>com.swifttype.app</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>SwiftType</string>
	<key>CFBundleDisplayName</key>
	<string>SwiftType</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${VERSION}</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSAccessibilityUsageDescription</key>
	<string>SwiftType requires Accessibility permissions to monitor keyboard typing and replace misspelled words instantaneously across macOS.</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2026 SwiftType Contributors. All rights reserved.</string>
</dict>
</plist>
EOF

echo "==> Zipping application bundle..."
cd "${BUILD_DIR}"
zip -r -y SwiftType.zip SwiftType.app
cd ..

echo "==> Build complete! Artifact generated at ${BUILD_DIR}/SwiftType.zip"
