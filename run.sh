#!/bin/bash
# Paper Assist 실행 스크립트
# Xcode Command Line Tools 가 설치되어 있어야 합니다. (xcode-select --install)
set -e
cd "$(dirname "$0")"
echo "▶︎ 빌드 후 실행합니다 (처음에는 시간이 걸립니다)…"
swift run -c release
