#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/SwiftType.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
LOGOS_SOURCE_DIR="Assets/Logos"
LOGOS_RESOURCES_DIR="${RESOURCES_DIR}/Logos"
APP_ICON_SOURCE="${LOGOS_SOURCE_DIR}/SwiftType logo.png"
ICONSET_DIR="${BUILD_DIR}/SwiftType.iconset"

echo "==> Building SwiftType release binary..."
if [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi
swift build -c release --arch arm64

echo "==> Creating macOS Application Bundle structure..."
rm -rf "${APP_DIR}" "${BUILD_DIR}/SwiftType.zip" "${ICONSET_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}" "${LOGOS_RESOURCES_DIR}"

echo "==> Copying binary into application bundle..."
if [ -f ".build/arm64-apple-macosx/release/SwiftType" ]; then
    cp ".build/arm64-apple-macosx/release/SwiftType" "${MACOS_DIR}/SwiftType"
else
    cp ".build/release/SwiftType" "${MACOS_DIR}/SwiftType"
fi
chmod +x "${MACOS_DIR}/SwiftType"

if [ -d "${LOGOS_SOURCE_DIR}" ]; then
    echo "==> Copying logo assets..."
    cp "${LOGOS_SOURCE_DIR}/Menubar logo black.png" "${LOGOS_RESOURCES_DIR}/Menubar logo black.png"
    cp "${LOGOS_SOURCE_DIR}/Menubar logo white.png" "${LOGOS_RESOURCES_DIR}/Menubar logo white.png"
    cp "${APP_ICON_SOURCE}" "${LOGOS_RESOURCES_DIR}/SwiftType logo.png"
fi

if [ -f "${APP_ICON_SOURCE}" ]; then
    echo "==> Generating application icon..."
    mkdir -p "${ICONSET_DIR}"
    sips -z 16 16 "${APP_ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
    sips -z 32 32 "${APP_ICON_SOURCE}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "${APP_ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
    sips -z 64 64 "${APP_ICON_SOURCE}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "${APP_ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
    sips -z 256 256 "${APP_ICON_SOURCE}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "${APP_ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
    sips -z 512 512 "${APP_ICON_SOURCE}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "${APP_ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
    sips -z 1024 1024 "${APP_ICON_SOURCE}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null
    iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/SwiftType.icns"
fi

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
	<key>CFBundleIconFile</key>
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
