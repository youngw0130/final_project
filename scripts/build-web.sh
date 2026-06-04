#!/usr/bin/env bash
# Flutter 웹 빌드 스크립트
# 터널 URL이 .run/tunnel-url.txt 에 있으면 자동 사용, 없으면 인수로 받음

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
MOBILE_DIR="$ROOT_DIR/apps/mobile"
TUNNEL_URL_FILE="$ROOT_DIR/.run/tunnel-url.txt"

# URL 결정
if [ -n "${1:-}" ]; then
  API_URL="$1/api"
elif [ -f "$TUNNEL_URL_FILE" ]; then
  TUNNEL_URL=$(cat "$TUNNEL_URL_FILE")
  API_URL="$TUNNEL_URL/api"
else
  echo "사용법: $0 <터널-URL>"
  echo "예:     $0 https://random-words.trycloudflare.com"
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Flutter 웹 빌드"
echo "  API_BASE_URL = $API_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$MOBILE_DIR"
flutter pub get
flutter build web \
  --release \
  --dart-define=API_BASE_URL="$API_URL"

echo ""
echo "✅ 빌드 완료: $MOBILE_DIR/build/web/"
echo ""
echo "─ Netlify 배포 방법 ────────────────────"
echo "  1. https://netlify.com 접속"
echo "  2. Sites → 'build/web' 폴더 드래그앤드롭"
echo "  (또는 Netlify CLI: netlify deploy --prod --dir build/web)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
