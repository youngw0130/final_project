#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  크레딧-N | 백엔드 (Spring Boot) 단독 실행
#  사용법: bash scripts/start-backend.sh
#  서버: http://localhost:8080
# ─────────────────────────────────────────────────────────────

set -e

PORT=8080
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/../apps/backend" && pwd)"

if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "⚠️  포트 $PORT 사용 중. 기존 프로세스 종료 후 재시작합니다."
  lsof -ti :$PORT | xargs kill -9 2>/dev/null
  sleep 1
fi

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   크레딧-N  ·  백엔드 (Spring Boot) 실행   ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""
echo "  📡  API 서버:    http://localhost:$PORT"
echo "  🗃️   H2 콘솔:     http://localhost:$PORT/h2-console"
echo "  📂  실행 경로:   $BACKEND_DIR"
echo ""
echo "  💡  처음 부팅 시 1분 정도 소요됩니다 (Gradle Daemon)."
echo "  ⛔  종료: Ctrl + C"
echo ""

cd "$BACKEND_DIR"
exec ./gradlew bootRun --console=plain
