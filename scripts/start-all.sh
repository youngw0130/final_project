#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  크레딧-N | 발표용 풀스택 실행 (백엔드 + 프로토타입)
#  사용법: bash scripts/start-all.sh
# ─────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/apps/backend"
DESIGN_DIR="$ROOT_DIR/design"

BACKEND_PORT=8080
DESIGN_PORT=3000
LOG_DIR="$ROOT_DIR/.run"
mkdir -p "$LOG_DIR"

# 기존 프로세스 정리
for PORT in $BACKEND_PORT $DESIGN_PORT; do
  if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  포트 $PORT 사용 중. 기존 프로세스 종료."
    lsof -ti :$PORT | xargs kill -9 2>/dev/null
  fi
done
sleep 1

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   크레딧-N  ·  발표용 풀스택 시작           ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# 1) 백엔드 백그라운드 실행
echo "  ▶ 백엔드 시작 중... (로그: $LOG_DIR/backend.log)"
(
  cd "$BACKEND_DIR"
  exec ./gradlew bootRun --console=plain
) > "$LOG_DIR/backend.log" 2>&1 &
BACKEND_PID=$!
echo "    PID=$BACKEND_PID"

# 백엔드 부팅 대기 (최대 90초)
echo "  ⏳ 백엔드 부팅 대기 중..."
for i in $(seq 1 90); do
  if curl -s -o /dev/null -w '%{http_code}' http://localhost:$BACKEND_PORT/api/auth/login -X POST -H 'Content-Type: application/json' -d '{}' 2>/dev/null | grep -qE '^(400|403|405)$'; then
    echo "  ✅ 백엔드 준비 완료 ($i초)"
    break
  fi
  sleep 1
  if [ $i -eq 90 ]; then
    echo "  ❌ 백엔드 부팅 시간 초과. 로그 확인: $LOG_DIR/backend.log"
    kill $BACKEND_PID 2>/dev/null
    exit 1
  fi
done

# 종료 시 백엔드도 같이 정리
trap "echo ''; echo '  🛑 종료 중...'; kill $BACKEND_PID 2>/dev/null; lsof -ti :$BACKEND_PORT | xargs kill -9 2>/dev/null; exit 0" INT TERM

echo ""
echo "  📡  백엔드:        http://localhost:$BACKEND_PORT"
echo "  🗃️   H2 콘솔:       http://localhost:$BACKEND_PORT/h2-console"
echo ""
echo "  🎨  프로토타입 허브:    http://localhost:$DESIGN_PORT/index.html"
echo "  🎮  데모 컨트롤 패널:    http://localhost:$DESIGN_PORT/demo.html"
echo "  📱  화면 시안:            http://localhost:$DESIGN_PORT/prototypes/01-dashboard.html"
echo ""
echo "  🔑  데모 계정: 감나빗 / test1234"
echo "  ⛔  종료: Ctrl + C"
echo ""

# 2) 프론트 정적 서버는 포그라운드
cd "$DESIGN_DIR"
exec python3 -m http.server $DESIGN_PORT --bind 127.0.0.1
