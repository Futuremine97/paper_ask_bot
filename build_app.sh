#!/bin/bash
# Paper Assist 를 더블클릭 실행 가능한 .app 번들로 패키징합니다.
# 요구: Xcode 또는 Command Line Tools (xcode-select --install)
set -e
cd "$(dirname "$0")"

APP_NAME="Paper Assist"
EXEC_NAME="PaperAssist"
BUNDLE_ID="com.paperassist.app"
VERSION="1.0.0"
APP_DIR="${APP_NAME}.app"

echo "▶︎ 1/4  릴리스 빌드 중… (처음에는 시간이 걸립니다)"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${EXEC_NAME}"
if [ ! -f "$BIN_PATH" ]; then
  echo "✗ 빌드 산출물을 찾을 수 없습니다: $BIN_PATH"
  exit 1
fi

echo "▶︎ 2/4  .app 번들 구조 생성 중…"
rm -rf "$APP_DIR"
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
cp "$BIN_PATH" "${APP_DIR}/Contents/MacOS/${EXEC_NAME}"

# 앱 아이콘 생성
if [ -d "assets/AppIcon.iconset" ] && command -v iconutil >/dev/null 2>&1; then
  iconutil -c icns "assets/AppIcon.iconset" -o "${APP_DIR}/Contents/Resources/AppIcon.icns" && echo "  ✓ 아이콘 적용"
fi

echo "▶︎ 3/4  Info.plist 작성 중…"
cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleExecutable</key>
    <string>${EXEC_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key><true/>
    </dict>
    <key>NSHumanReadableCopyright</key>
    <string>Paper Assist</string>
</dict>
</plist>
PLIST

echo "▶︎ 4/4  애드혹 서명 중…"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "  (서명 건너뜀 — 실행에는 문제 없습니다)"

echo ""
echo "✅ 완료!  ${APP_DIR} 생성됨"
echo "   Finder 에서 더블클릭하거나:  open \"${APP_DIR}\""
echo ""
echo "   응용 프로그램 폴더로 옮기려면:"
echo "   mv \"${APP_DIR}\" /Applications/"
