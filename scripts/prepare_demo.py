#!/usr/bin/env python3
"""
발표 데이터 준비 스크립트
- 참여자 한글 이름 계정 생성
- 감나빗 링크스코어 750점(골드) 조정
- 시연용 ACTIVE 모임 준비 (정산 데모용)
"""

import requests
import time
import sys

BASE = "https://final-project-cx68.onrender.com/api"

MAIN = ("감나빗", "12345678")

# 한글 이름 계정 (username이 곧 화면 표시명)
KOREAN_ACCOUNTS = [
    ("이민수", "minsu_kr@creditn.com",   "12345678"),
    ("김소라", "sora_kr@creditn.com",    "12345678"),
    ("박현우", "hyunwoo_kr@creditn.com", "12345678"),
    ("최서연", "seoyeon_kr@creditn.com", "12345678"),
]

# 시연용 ACTIVE 모임 (정산 데모)
DEMO_MOIM = {
    "title": "팀 저녁 회식",
    "emoji": "🍽️",
    "description": "Q2 성과 달성 기념 팀 저녁 회식",
    "depositPerPerson": 35000,
    "bufferRate": 0.1,
    "targetParticipantCount": 5,
    "scheduledAt": "2026-06-20T19:00:00",
}

# QR 결제 내역 (ACTIVE 모임에 추가)
DEMO_PAYMENTS = [
    {"merchantName": "한우마루 강남점",  "category": "식품료", "amount": 89000},
    {"merchantName": "GS25 강남역점",    "category": "식품료", "amount": 24500},
    {"merchantName": "스타벅스 강남점",  "category": "카페",   "amount": 32500},
]


def H(token=None):
    h = {"Content-Type": "application/json"}
    if token:
        h["Authorization"] = f"Bearer {token}"
    return h


def ok(r, label=""):
    if r.status_code >= 400:
        print(f"  ⚠️  {label} ({r.status_code}): {r.text[:120]}")
        return None
    try:
        return r.json()
    except Exception:
        return {}


def login(username, password):
    r = requests.post(f"{BASE}/auth/login",
                      headers=H(), json={"username": username, "password": password}, timeout=30)
    d = ok(r, f"login:{username}")
    return d.get("token") if d else None


def signup_or_login(username, email, password):
    r = requests.post(f"{BASE}/auth/signup", headers=H(),
                      json={"username": username, "email": email, "password": password}, timeout=30)
    if r.status_code == 200:
        print(f"  ✅ 계정 생성: {username}")
        return r.json().get("token")
    # 이미 존재하면 로그인
    token = login(username, password)
    if token:
        print(f"  ♻️  기존 계정 사용: {username}")
    return token


def get_moims(token):
    r = requests.get(f"{BASE}/moims/my", headers=H(token), timeout=15)
    return ok(r, "getMyMoims") or []


def get_participants(token, moim_id):
    r = requests.get(f"{BASE}/moims/{moim_id}/participants", headers=H(token), timeout=15)
    return ok(r, "getParticipants") or []


def confirm_deposit(token, moim_id, user_id):
    r = requests.post(f"{BASE}/moims/{moim_id}/deposit/confirm?userId={user_id}",
                      headers=H(token), timeout=15)
    return ok(r, f"confirmDeposit uid={user_id}")


def create_moim(token, data):
    r = requests.post(f"{BASE}/moims", headers=H(token), json=data, timeout=30)
    return ok(r, "createMoim")


def join_moim(token, invite_code):
    r = requests.post(f"{BASE}/moims/join?inviteCode={invite_code}",
                      headers=H(token), timeout=15)
    return ok(r, f"joinMoim:{invite_code}")


def add_payment(token, moim_id, merchant, category, amount):
    r = requests.post(f"{BASE}/moims/{moim_id}/payments", headers=H(token),
                      json={"merchantName": merchant, "category": category, "amount": amount}, timeout=15)
    return ok(r, f"payment:{merchant}")


def get_profile(token):
    r = requests.get(f"{BASE}/users/me", headers=H(token), timeout=15)
    return ok(r, "getProfile") or {}


# ─────────────────────────────────────────────
# STEP 1: 한글 이름 계정 준비
# ─────────────────────────────────────────────
print("\n━━━ STEP 1: 한글 참여자 계정 준비 ━━━")
korean_tokens = {}
for (username, email, password) in KOREAN_ACCOUNTS:
    token = signup_or_login(username, email, password)
    if token:
        korean_tokens[username] = token

# ─────────────────────────────────────────────
# STEP 2: 감나빗 로그인 & 현재 상태 확인
# ─────────────────────────────────────────────
print("\n━━━ STEP 2: 감나빗 상태 확인 ━━━")
main_token = login(*MAIN)
if not main_token:
    print("❌ 감나빗 로그인 실패"); sys.exit(1)

profile = get_profile(main_token)
current_score = profile.get("linkScore", 0)
print(f"  현재 링크스코어: {current_score}점")

# ─────────────────────────────────────────────
# STEP 3: 기존 OPEN 모임에서 미입금 확인 처리 (+10씩)
# ─────────────────────────────────────────────
print("\n━━━ STEP 3: 기존 OPEN 모임 미입금 처리 ━━━")
my_moims = get_moims(main_token)
gamnabit_id = profile.get("id", 1)

for moim in my_moims:
    if moim["status"] != "OPEN":
        continue
    ps = get_participants(main_token, moim["id"])
    for p in ps:
        if p["userId"] == gamnabit_id and p["depositStatus"] in ("PENDING", "OVERDUE"):
            result = confirm_deposit(main_token, moim["id"], gamnabit_id)
            if result:
                print(f"  ✅ {moim['title']} 입금 확인 완료 (+10)")
            time.sleep(0.3)

# ─────────────────────────────────────────────
# STEP 4: 시연용 ACTIVE 모임 생성 (중복 방지)
# ─────────────────────────────────────────────
print("\n━━━ STEP 4: 시연용 ACTIVE 모임 준비 ━━━")

# 이미 존재하는지 확인
existing_moims = get_moims(main_token)
demo_moim_data = next(
    (m for m in existing_moims if m["title"] == DEMO_MOIM["title"]), None
)

if demo_moim_data:
    print(f"  ♻️  이미 존재: {demo_moim_data['title']} (id={demo_moim_data['id']}, status={demo_moim_data['status']})")
    demo_id = demo_moim_data["id"]
    invite_code = demo_moim_data["inviteCode"]
else:
    moim = create_moim(main_token, DEMO_MOIM)
    if not moim:
        print("❌ 모임 생성 실패"); sys.exit(1)
    demo_id = moim["id"]
    invite_code = moim["inviteCode"]
    print(f"  ✅ 모임 생성: {DEMO_MOIM['title']} (id={demo_id}, 초대코드: {invite_code})")
    time.sleep(0.5)

# 한글 참여자들 초대 참여
print("  참여자 초대 중...")
for username, token in korean_tokens.items():
    r = join_moim(token, invite_code)
    if r:
        print(f"    ✅ {username} 참여")
    else:
        print(f"    ♻️  {username} 이미 참여")
    time.sleep(0.3)

# 모든 참여자 입금 확인 (감나빗 포함)
print("  입금 확인 처리...")
time.sleep(0.5)
ps = get_participants(main_token, demo_id)
for p in ps:
    if p["depositStatus"] in ("PENDING", "OVERDUE"):
        confirm_deposit(main_token, demo_id, p["userId"])
        print(f"    ✅ {p['username']} 입금 확인 (+10)")
        time.sleep(0.3)

# 현재 모임 상태 확인
time.sleep(0.5)
moims_now = get_moims(main_token)
demo_now = next((m for m in moims_now if m["id"] == demo_id), None)
if demo_now:
    print(f"  📊 모임 상태: {demo_now['status']}")

# QR 결제 내역 추가 (지출 내역이 없을 때만)
if demo_now and demo_now.get("totalSpent", 0) == 0:
    print("  QR 결제 내역 추가...")
    for p in DEMO_PAYMENTS:
        r = add_payment(main_token, demo_id, p["merchantName"], p["category"], p["amount"])
        if r:
            print(f"    ✅ {p['merchantName']} -{p['amount']:,}원")
        time.sleep(0.3)
else:
    print(f"  ♻️  지출 내역 이미 있음 ({demo_now.get('totalSpent', 0):,.0f}원)")

# ─────────────────────────────────────────────
# STEP 5: 링크스코어 추가 조정 (목표: 750+)
# ─────────────────────────────────────────────
print("\n━━━ STEP 5: 링크스코어 조정 ━━━")
profile = get_profile(main_token)
final_score = profile.get("linkScore", 0)
print(f"  최종 링크스코어: {final_score}점")

if final_score >= 700:
    grade = "플래티넘" if final_score >= 800 else "골드"
    print(f"  🥇 {grade} 달성!")
elif final_score >= 600:
    print(f"  🥈 실버 ({final_score}점) - 목표까지 {700 - final_score}점 부족")
else:
    print(f"  ⚠️  {final_score}점 - 더 많은 활동 필요")

# ─────────────────────────────────────────────
# 완료 요약
# ─────────────────────────────────────────────
print("\n━━━ 발표 준비 완료 ━━━")
print(f"  📱 메인 계정:  감나빗 / 12345678")
print(f"  🏆 링크스코어: {final_score}점")
print(f"  🍽️  시연 모임:  {DEMO_MOIM['title']} (id={demo_id})")
print(f"  👥 참여자:     이민수, 김소라, 박현우, 최서연")
if demo_now and demo_now.get("status") == "ACTIVE":
    total_paid = int(demo_now.get("totalDeposited", 0))
    total_spent = int(demo_now.get("totalSpent", 0))
    print(f"  💰 에스크로:   입금 {total_paid:,}원 / 지출 {total_spent:,}원")
    print(f"  🎬 정산 데모:  정산하기 버튼으로 바로 시연 가능")
