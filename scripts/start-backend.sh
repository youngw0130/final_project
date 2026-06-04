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
TEMP_PROPS="/tmp/creditn-runtime.properties"

if [ ! -f "$ENV_FILE" ]; then
  echo "❌  .env 파일을 찾을 수 없습니다: $ENV_FILE"
  exit 1
fi

# .env → Spring properties 변환 함수
get_env() {
  grep "^$1=" "$ENV_FILE" | head -1 | cut -d'=' -f2- | sed "s/^['\"]//;s/['\"]$//"
}

DB_URL=$(get_env SPRING_DATASOURCE_URL)
DB_USER=$(get_env SPRING_DATASOURCE_USERNAME)
DB_PASS=$(get_env SPRING_DATASOURCE_PASSWORD)
JWT_SECRET=$(get_env JWT_SECRET)
PO_STORE=$(get_env PORTONE_STORE_ID)
PO_SECRET=$(get_env PORTONE_API_SECRET)
PO_CHANNEL=$(get_env PORTONE_CHANNEL_KEY)
PO_WEBHOOK=$(get_env PORTONE_WEBHOOK_SECRET)

if [ -z "$DB_URL" ]; then
  echo "❌  .env에 SPRING_DATASOURCE_URL이 없습니다."
  exit 1
fi

# 임시 Spring properties 파일 생성 (env var 상속 우회)
cat > "$TEMP_PROPS" <<EOF
spring.datasource.url=${DB_URL}
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASS}
spring.datasource.driver-class-name=org.postgresql.Driver
jwt.secret=${JWT_SECRET:-credit-n-secret-key-for-jwt-token-signing-must-be-long-enough-256bits}
portone.store-id=${PO_STORE:-demo-store-id}
portone.api-secret=${PO_SECRET:-demo-secret}
portone.channel-key=${PO_CHANNEL:-demo-channel-key}
portone.webhook-secret=${PO_WEBHOOK:-demo-webhook-secret}
EOF

# 포트 정리
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "⚠️  포트 $PORT 사용 중 — 기존 프로세스 종료"
  lsof -ti :$PORT | xargs kill -9 2>/dev/null || true
fi

cd "$BACKEND_DIR"

# JAR 빌드 (없는 경우)
JAR=$(ls build/libs/credit-n-*.jar 2>/dev/null | grep -v plain | head -1)
if [ -z "$JAR" ]; then
  echo "📦  bootJar 빌드 중..."
  ./gradlew bootJar -x test --quiet
  JAR=$(ls build/libs/credit-n-*.jar | grep -v plain | head -1)
fi

echo ""
echo "  API: http://localhost:$PORT"
echo "  DB:  ${DB_URL%%\?*}"
echo "  JAR: $JAR"
echo ""

exec java -Xmx512m \
  -jar "$JAR" \
  --spring.profiles.active=prod \
  --spring.config.additional-location="file:$TEMP_PROPS"
