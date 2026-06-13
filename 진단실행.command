#!/bin/bash
# 진단용: 앱을 '터미널에서 직접' 실행해 오류/충돌 메시지를 화면에 표시합니다.
# (open 으로 띄우면 충돌 원인이 안 보이기 때문에, 여기서는 직접 실행합니다.)
cd "$(dirname "$0")"
EXEC_NAME="PaperAssist"

if ! command -v swift >/dev/null 2>&1; then
  echo "✗ Swift 가 없습니다. 먼저:  xcode-select --install"
  read -n 1 -s -r -p "아무 키나 누르면 닫힙니다…"; exit 1
fi

echo "▶︎ 빌드 중…"
if ! swift build -c release 2>&1; then
  echo ""
  echo "✗ 빌드(컴파일) 실패입니다. 위의 빨간/오류 메시지 전체를 복사해 알려주세요."
  read -n 1 -s -r -p "아무 키나 누르면 닫힙니다…"; exit 1
fi

BIN="$(swift build -c release --show-bin-path)/${EXEC_NAME}"
echo ""
echo "▶︎ 앱을 직접 실행합니다. 메뉴바에 돋보기 아이콘이 나타나야 합니다."
echo "   (이 창을 닫으면 앱도 종료됩니다. 종료하려면 Ctrl+C)"
echo "   만약 곧바로 충돌하면 아래에 오류가 출력됩니다 — 그 내용을 복사해 알려주세요."
echo "---------------------------------------------------------------"
# 기존 인스턴스 정리 후 포그라운드 실행
pkill -x "$EXEC_NAME" 2>/dev/null || true
sleep 1
"$BIN"
echo "---------------------------------------------------------------"
echo "앱이 종료되었습니다. 위에 오류가 있으면 복사해 알려주세요."
read -n 1 -s -r -p "아무 키나 누르면 닫힙니다…"
