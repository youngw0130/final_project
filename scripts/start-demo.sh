#!/usr/bin/env bash
# Credit-N 데모 시작 스크립트
# 백엔드(로컬) + Cloudflare Tunnel + Neon DB

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$ROOT_DIR/apps/backend"
MOBILE_DIR="$ROOT_DIR/apps/mobile"
ENV_FILE="$ROOT_DIR/.env"
LOG_DIR="$ROOT_DIR/.run"

mkdir -p "$LOG_DIR"

# ── 1. .env 로드 ──────────────────────────────────────────────────────────────
if [ ! -f "$ENV_FILE" ]; then
  echo "❌  .env 파일이 없습니다: $ENV_FILE"
  exit 1
fi
set -a; source "$ENV_FILE"; set +a

# 필수 환경변수 확인
for var in SPRING_DATASOURCE_URL SPRING_DATASOURCE_USERNAME SPRING_DATASOURCE_PASSWORD JWT_SECRET; do
  if [ -z "${!var:-}" ]; then
    echo "❌  필수 환경변수 누락: $var (.env 파일 확인)"
    exit 1
  fi
done

export SPRING_PROFILES_ACTIVE=prod

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Credit-N Demo Launcher"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ── 2. 이전 프로세스 정리 ───────────────────────────────────────────────────────
echo "[1/4] 기존 프로세스 정리..."
pkill -f 'credit.*n.*application' 2>/dev/null || true
pkill -f 'cloudflared' 2>/dev/null || true
sleep 1

# ── 3. 백엔드 빌드 & 실행 ──────────────────────────────────────────────────────
echo "[2/4] 백엔드 빌드 중..."
cd "$BACKEND_DIR"
./gradlew bootJar -q -x test 2>&1 | tail -5

JAR=$(ls build/libs/*.jar | grep -v plain | head -1)
echo "      JAR: $JAR"

echo "[3/4] 백엔드 시작 (Neon DB 연결)..."
java -jar \
  -XX:+UseContainerSupport \
  -Dspring.profiles.active=prod \
  "$JAR" \
  > "$LOG_DIR/backend.log" 2>&1 &
BACKEND_PID=$!
echo "      PID: $BACKEND_PID"

# 헬스체크 대기 (최대 60초)
echo "      헬스체크 대기..."
for i in $(seq 1 30); do
  if curl -sf http://localhost:8080/actuator/health > /dev/null 2>&1; then
    echo "      ✅ 백엔드 정상 기동"
    break
  fi
  if ! kill -0 $BACKEND_PID 2>/dev/null; then
    echo "      ❌ 백엔드 기동 실패. 로그:"
    tail -30 "$LOG_DIR/backend.log"
    exit 1
  fi
  sleep 2
  printf "."
done

# ── 4. Cloudflare Tunnel 시작 ───────────────────────────────────────────────
echo "[4/4] Cloudflare Tunnel 시작..."
cloudflared tunnel --url http://localhost:8080 \
  > "$LOG_DIR/cloudflared.log" 2>&1 &
CF_PID=$!

# 터널 URL 추출 (최대 30초)
TUNNEL_URL=""
for i in $(seq 1 30); do
  TUNNEL_URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_DIR/cloudflared.log" 2>/dev/null | head -1 || true)
  [ -n "$TUNNEL_URL" ] && break
  sleep 1
done

if [ -z "$TUNNEL_URL" ]; then
  echo "⚠️  터널 URL을 가져오지 못했습니다. 로그 확인: $LOG_DIR/cloudflared.log"
  TUNNEL_URL="(터널 URL 수동 확인 필요)"
fi

# ── 완료 출력 ──────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ 데모 환경 준비 완료"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  백엔드 로컬:   http://localhost:8080"
echo "  공개 터널:     $TUNNEL_URL"
echo "  헬스체크:      $TUNNEL_URL/actuator/health"
echo ""
echo "  ─ Flutter 웹 빌드 명령 ─────────────────"
echo "  cd $MOBILE_DIR"
echo "  flutter build web --dart-define=API_BASE_URL=$TUNNEL_URL/api"
echo ""
echo "  ─ 백엔드 로그 ──────────────────────────"
echo "  tail -f $LOG_DIR/backend.log"
echo ""
echo "  ─ 종료하려면 ───────────────────────────"
echo "  kill $BACKEND_PID $CF_PID"
echo "  (또는 scripts/stop-demo.sh)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 터널 URL을 파일에 저장 (Flutter 빌드 스크립트에서 참조)
echo "$TUNNEL_URL" > "$LOG_DIR/tunnel-url.txt"
