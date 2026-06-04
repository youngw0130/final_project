#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  크레딧-N | Flutter 웹 빌드
#  사용법: bash scripts/build-web.sh https://xxx.trycloudflare.com
#          (인자 없으면 /tmp/creditn-tunnel-url.txt 에서 읽음)
# ─────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/../apps/mobile" && pwd)"

# 터널 URL 결정
if [ -n "$1" ]; then
  TUNNEL_URL="$1"
elif [ -f "/tmp/creditn-tunnel-url.txt" ]; then
  TUNNEL_URL=$(cat /tmp/creditn-tunnel-url.txt)
else
  echo "사용법: bash scripts/build-web.sh https://xxx.trycloudflare.com"
  exit 1
fi

API_URL="${TUNNEL_URL}/api"

echo ""
echo "Flutter 웹 빌드 시작"
echo "API URL: $API_URL"
echo ""

cd "$MOBILE_DIR"

flutter pub get

flutter build web \
  --release \
  --dart-define=API_BASE_URL="$API_URL"

BUILD_DIR="$MOBILE_DIR/build/web"
echo ""
echo "빌드 완료: $BUILD_DIR"
echo ""
echo "Netlify 배포:"
echo "  1. https://app.netlify.com/drop 접속"
echo "  2. $BUILD_DIR 폴더를 드래그앤드롭"
echo ""
