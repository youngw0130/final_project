#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  크레딧-N | 시연용 APK 빌드 (로컬 백엔드 연결)
#
#  사용법:
#    bash scripts/build-apk-demo.sh                         # /tmp/creditn-tunnel-url.txt 자동 읽기
#    bash scripts/build-apk-demo.sh https://xxx.trycloudflare.com
#
#  사전 조건:
#    1) bash scripts/start-all.sh    (백엔드 실행 + 시드 완료)
#    2) bash scripts/start-tunnel.sh (터널 URL 확보)
# ─────────────────────────────────────────────────────────────

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MOBILE_DIR="$(cd "$SCRIPT_DIR/../apps/mobile" && pwd)"

# ── 터널 URL 결정 ──────────────────────────────────────────
if [ -n "$1" ]; then
  TUNNEL_URL="$1"
elif [ -f "/tmp/creditn-tunnel-url.txt" ]; then
  TUNNEL_URL=$(cat /tmp/creditn-tunnel-url.txt)
else
  echo "❌  터널 URL이 없습니다."
  echo "    먼저 bash scripts/start-tunnel.sh 를 실행하거나"
  echo "    URL을 인자로 전달하세요:"
  echo "    bash scripts/build-apk-demo.sh https://xxx.trycloudflare.com"
  exit 1
fi

# 후행 슬래시 제거
TUNNEL_URL="${TUNNEL_URL%/}"
API_URL="${TUNNEL_URL}/api"

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   크레딧-N  ·  시연용 APK 빌드              ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""
echo "  API URL: $API_URL"
echo ""

cd "$MOBILE_DIR"

flutter pub get

flutter build apk \
  --release \
  --dart-define=API_BASE_URL="$API_URL"

APK_PATH="$MOBILE_DIR/build/app/outputs/flutter-apk/app-release.apk"

echo ""
echo "  ✅ APK 빌드 완료"
echo "  📦 경로: $APK_PATH"
echo ""
echo "  ─────────────────────────────────────────────"
echo "  📱 설치 방법"
echo "    USB 연결 후:"
echo "      adb install -r \"$APK_PATH\""
echo ""
echo "  또는 파일 앱으로 직접 전송 후 설치"
echo "  ─────────────────────────────────────────────"
echo ""
echo "  🔑 로그인: 감나빗 / test1234"
echo ""
