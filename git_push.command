#!/bin/bash
# 이 파일을 더블클릭하면: 보안에 안전한 파일만 골라 커밋하고 GitHub로 push 합니다.
# (GitHub 로그인/토큰은 주인님 맥의 git 인증을 그대로 사용합니다. 이 스크립트에는 어떤 비밀번호도 들어있지 않습니다.)
set -e
cd "$(dirname "$0")"

REMOTE="https://github.com/Futuremine97/paper_ask_bot.git"

echo "▶︎ git 저장소 준비…"
# 샌드박스에서 남았을 수 있는 잠금 파일 정리
rm -f .git/index.lock 2>/dev/null || true

git init -q
git config user.name "Futuremine97"
git config user.email "Futuremine97@users.noreply.github.com"

echo "▶︎ 변경사항 스테이징 (.gitignore 로 .build / *.app 자동 제외)…"
git add -A

echo "▶︎ 커밋 대상 미리보기:"
git status --short

# 커밋 (변경 없으면 건너뜀)
if ! git diff --cached --quiet; then
  git commit -m "Paper Assist: 스크린샷 AI 분석 (macOS 앱 + Chrome 확장)"
else
  echo "  (새 커밋 없음 — 이미 커밋됨)"
fi

git branch -M main

# 리모트 설정
if git remote | grep -q '^origin$'; then
  git remote set-url origin "$REMOTE"
else
  git remote add origin "$REMOTE"
fi

echo ""
echo "▶︎ GitHub로 push 합니다. (처음이면 로그인 창이 뜰 수 있습니다)"
echo "   저장소: $REMOTE"
echo "---------------------------------------------------------------"
if git push -u origin main; then
  echo "---------------------------------------------------------------"
  echo "✅ push 완료!  https://github.com/Futuremine97/paper_ask_bot 에서 확인하세요."
else
  echo "---------------------------------------------------------------"
  echo "✗ push 실패. 가장 흔한 원인:"
  echo "   1) GitHub 로그인 안 됨 → 'gh auth login' 또는 git 자격증명 설정 후 다시 실행"
  echo "   2) 원격에 이미 다른 내용이 있음 → 'git pull --rebase origin main' 후 다시 실행"
  echo "   3) 저장소가 없음 → GitHub에서 paper_ask_bot 저장소를 먼저 만들어 주세요"
fi
echo ""
read -n 1 -s -r -p "아무 키나 누르면 닫힙니다…"
