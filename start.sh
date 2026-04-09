#!/bin/bash
# ─────────────────────────────────────────────────────────────
#  크레딧-N | html.to.design 로컬 서버
#  사용법: bash start.sh
# ─────────────────────────────────────────────────────────────

PORT=3000
DIR="$(cd "$(dirname "$0")" && pwd)"

# 이미 같은 포트가 사용 중이면 종료
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
  echo "⚠️  포트 $PORT 이미 사용 중. 기존 프로세스 종료 후 재시작합니다."
  lsof -ti :$PORT | xargs kill -9 2>/dev/null
  sleep 1
fi

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   크레딧-N  ·  Figma 임포트용 로컬 서버     ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""
echo "  📡  서버 주소:  http://localhost:$PORT"
echo ""
echo "  ┌─────────────────────────────────────────────┐"
echo "  │  html.to.design 플러그인 → URL 탭에 입력   │"
echo "  └─────────────────────────────────────────────┘"
echo ""
echo "  01  메인 대시보드     →  http://localhost:$PORT/index.html"
echo "  02  모임 생성         →  http://localhost:$PORT/create-group.html"
echo "  03  에스크로 상세     →  http://localhost:$PORT/escrow-detail.html"
echo "  04  QR 결제           →  http://localhost:$PORT/qr-payment.html"
echo "  05  정산 리포트       →  http://localhost:$PORT/settlement-report.html"
echo "  06  링크스코어 분석   →  http://localhost:$PORT/link-score-insights.html"
echo ""
echo "  💡  팁: Figma 데스크톱 앱에서만 localhost URL이 작동합니다."
echo "  ⛔  종료: Ctrl + C"
echo ""

cd "$DIR"
python3 -m http.server $PORT --bind 127.0.0.1
