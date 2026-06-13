#!/bin/bash
# 이 파일을 더블클릭하면: 최신 코드로 빌드 → .app 갱신 → 실행 합니다.
cd "$(dirname "$0")"

EXEC_NAME="PaperAssist"
APP="Paper Assist.app"

# Swift 설치 확인
if ! command -v swift >/dev/null 2>&1; then
  echo "✗ Swift(개발 도구)가 없습니다. 아래 명령으로 설치 후 다시 시도하세요:"
  echo "    xcode-select --install"
  read -n 1 -s -r -p "아무 키나 누르면 닫힙니다…"
  exit 1
fi

echo "▶︎ 1/3  최신 코드로 빌드 중… (처음만 오래 걸리고 이후엔 빠릅니다)"
if ! swift build -c release; then
  echo "✗ 빌드 실패. 위 오류 메시지를 복사해 알려주세요."
  read -n 1 -s -r -p "아무 키나 누르면 닫힙니다…"
  exit 1
fi

BIN="$(swift build -c release --show-bin-path)/${EXEC_NAME}"

echo "▶︎ 2/3  앱 번들 갱신 중…"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"
cp "$BIN" "${APP}/Contents/MacOS/${EXEC_NAME}"

# 앱 아이콘 생성 (assets/AppIcon.iconset → AppIcon.icns)
if [ -d "assets/AppIcon.iconset" ] && command -v iconutil >/dev/null 2>&1; then
  iconutil -c icns "assets/AppIcon.iconset" -o "${APP}/Contents/Resources/AppIcon.icns" && echo "  ✓ 아이콘 적용"
fi

cat > "${APP}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Paper Assist</string>
    <key>CFBundleDisplayName</key><string>Paper Assist</string>
    <key>CFBundleExecutable</key><string>PaperAssist</string>
    <key>CFBundleIdentifier</key><string>com.paperassist.app</string>
    <key>CFBundleVersion</key><string>1.0.0</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsLocalNetworking</key><true/>
    </dict>
</dict>
</plist>
PLIST

xattr -dr com.apple.quarantine "$APP" 2>/dev/null || true

echo "▶︎ 3/3  실행 중…"
# 이미 실행 중이면 종료 후 재실행 (최신 버전 반영)
pkill -x "$EXEC_NAME" 2>/dev/null || true
sleep 1
open "$APP"

echo ""
echo "✅ 실행됐습니다!"
echo "   화면 오른쪽 위 '메뉴바'에 돋보기 아이콘이 생깁니다. 클릭하면 메뉴가 나옵니다."
echo "   (이 터미널 창은 닫으셔도 됩니다.)"
sleep 2
