#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  크레딧-N | 백엔드 (Spring Boot) — Neon PostgreSQL 연결
#  사용법: bash scripts/start-backend.sh
#  서버: http://localhost:8080
# ─────────────────────────────────────────────────────────────

set -e

PORT=8080
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/apps/backend"
ENV_FILE="$ROOT_DIR/.env"

# .env 로드
if [ -f "$ENV_FILE" ]; then
  set -o allexport
  source "$ENV_FILE"
  set +o allexport
else
  echo "❌  .env 파일을 찾을 수 없습니다: $ENV_FILE"
  exit 1
fi

# 필수 환경변수 체크
if [ -z "$SPRING_DATASOURCE_URL" ]; then
  echo "❌  .env에 SPRING_DATASOURCE_URL이 없습니다."
  exit 1
fi

if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "⚠️  포트 $PORT 사용 중. 기존 프로세스 종료합니다."
  lsof -ti :$PORT | xargs kill -9 2>/dev/null
  sleep 1
fi

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   크레딧-N  ·  백엔드 (Spring Boot) 실행   ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""
echo "  📡  API 서버:  http://localhost:$PORT"
echo "  🗄️   DB:       Neon PostgreSQL (prod)"
echo "  ⛔  종료:     Ctrl + C"
echo ""

cd "$BACKEND_DIR"
exec ./gradlew bootRun \
  --args='--spring.profiles.active=prod' \
  --console=plain
