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

# .env 로드 (전체 export)
if [ ! -f "$ENV_FILE" ]; then
  echo "❌  .env 파일을 찾을 수 없습니다: $ENV_FILE"
  exit 1
fi

# 포트 정리
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "⚠️  포트 $PORT 사용 중 — 기존 프로세스 종료"
  lsof -ti :$PORT | xargs kill -9 2>/dev/null || true
  sleep 1
fi

cd "$BACKEND_DIR"

# JAR 빌드 (아직 없는 경우)
JAR=$(ls build/libs/credit-n-*.jar 2>/dev/null | head -1)
if [ -z "$JAR" ]; then
  echo "📦  bootJar 빌드 중..."
  ./gradlew bootJar -x test --quiet
  JAR=$(ls build/libs/credit-n-*.jar | head -1)
fi

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   크레딧-N  ·  백엔드 (Spring Boot) 실행   ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""
echo "  📡  API: http://localhost:$PORT"
echo "  🗄️   DB:  Neon PostgreSQL"
echo "  ⛔  종료: Ctrl + C"
echo ""

# env vars를 명시적으로 앞에 붙여 java 실행 (가장 확실한 방법)
exec env $(grep -v '^#' "$ENV_FILE" | grep '=' | xargs) \
  java -Xmx512m \
  -jar "$JAR" \
  --spring.profiles.active=prod
