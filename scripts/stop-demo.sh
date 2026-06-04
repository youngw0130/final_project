#!/usr/bin/env bash
echo "Credit-N 데모 종료 중..."
pkill -f 'credit.*n.*application' 2>/dev/null && echo "  ✅ 백엔드 종료" || echo "  ─ 백엔드 프로세스 없음"
pkill -f 'cloudflared' 2>/dev/null && echo "  ✅ Cloudflare Tunnel 종료" || echo "  ─ cloudflared 프로세스 없음"
echo "완료"
