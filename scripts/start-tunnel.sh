#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  크레딧-N | Cloudflare Quick Tunnel
#  사용법: bash scripts/start-tunnel.sh
#  백엔드가 먼저 실행 중이어야 합니다 (localhost:8080)
# ─────────────────────────────────────────────────────────────

set -e

PORT=8080
LOG_FILE="/tmp/cloudflared-creditn.log"

# cloudflared 설치 확인
if ! command -v cloudflared &>/dev/null; then
  echo "❌  cloudflared가 설치되어 있지 않습니다."
  echo "    brew install cloudflared"
  exit 1
fi

# 백엔드 실행 확인
if ! lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "❌  localhost:$PORT 에서 백엔드가 실행 중이 아닙니다."
  echo "    먼저 bash scripts/start-backend.sh 를 실행하세요."
  exit 1
fi

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   크레딧-N  ·  Cloudflare Tunnel 시작       ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""
echo "  🔗  터널 URL을 받는 중... (10~20초 소요)"
echo ""

# 터널 실행 및 URL 캡처
cloudflared tunnel --url "http://localhost:$PORT" --logfile "$LOG_FILE" &
TUNNEL_PID=$!

# URL이 로그에 나타날 때까지 대기 (최대 30초)
TUNNEL_URL=""
for i in $(seq 1 30); do
  sleep 1
  TUNNEL_URL=$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "$LOG_FILE" 2>/dev/null | head -1)
  if [ -n "$TUNNEL_URL" ]; then
    break
  fi
done

if [ -z "$TUNNEL_URL" ]; then
  echo "❌  터널 URL을 가져오지 못했습니다. 로그 확인: $LOG_FILE"
  kill $TUNNEL_PID 2>/dev/null
  exit 1
fi

echo "  ✅  터널 URL:  $TUNNEL_URL"
echo "  📱  Flutter API URL:  $TUNNEL_URL/api"
echo ""
echo "  ─────────────────────────────────────────────"
echo "  다음 명령어로 Flutter 웹 빌드:"
echo ""
echo "    bash scripts/build-web.sh $TUNNEL_URL"
echo ""
echo "  ─────────────────────────────────────────────"
echo "  ⛔  종료: Ctrl + C"
echo ""

# 터널 URL 파일 저장 (build-web.sh에서 읽을 수 있도록)
echo "$TUNNEL_URL" > /tmp/creditn-tunnel-url.txt

# 터널 유지
wait $TUNNEL_PID
