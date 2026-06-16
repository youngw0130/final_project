#!/usr/bin/env python3
"""
시연용 데모 데이터 시드 스크립트
Render 백엔드에 계정/모임/입금/정산 데이터를 생성합니다.

사용법:
    python3 scripts/seed_demo.py

생성되는 데이터:
    계정 : 감나빗 / 12345678  (메인 발표용)
    모임 :
      ✈️  제주도 여행   - ACTIVE  (5/5 입금, 지출 2건)
      🍽️  팀 회식      - OPEN    (2/5 입금, 모집 중)
      🎓  졸업 파티    - CLOSED  (5/5 입금 → 정산 완료)
      💻  개발 스터디  - ACTIVE  (4/4 입금, 지출 1건)
"""

import sys
import time
import requests

BASE_URL = "https://final-project-cx68.onrender.com/api"

MAIN_USER = ("감나빗", "gamnabit@creditn.com", "12345678")

EXTRA_ACCOUNTS = [
    ("dm_minsu",   "dm_minsu@demo.com",   "Demo1234!"),
    ("dm_sora",    "dm_sora@demo.com",    "Demo1234!"),
    ("dm_hyunwoo", "dm_hyunwoo@demo.com", "Demo1234!"),
    ("dm_seoyeon", "dm_seoyeon@demo.com", "Demo1234!"),
]

# ─────────────────────────────────────────────
# 헬퍼
# ─────────────────────────────────────────────

def _headers(token=None):
    h = {"Content-Type": "application/json"}
    if token:
        h["Authorization"] = f"Bearer {token}"
    return h

def _ok(r, label=""):
    if r.status_code >= 400:
        print(f"  ❌ {label} 실패 ({r.status_code}): {r.text[:200]}")
        return None
    return r.json()

def signup(username, email, password):
    r = requests.post(f"{BASE_URL}/auth/signup",
                      headers=_headers(),
                      json={"username": username, "email": email, "password": password},
                      timeout=60)
    return _ok(r, f"signup:{username}")

def login(username, password):
    r = requests.post(f"{BASE_URL}/auth/login",
                      headers=_headers(),
                      json={"username": username, "password": password},
                      timeout=60)
    return _ok(r, f"login:{username}")

def create_moim(token, data):
    r = requests.post(f"{BASE_URL}/moims",
                      headers=_headers(token), json=data, timeout=30)
    return _ok(r, "createMoim")

def join_moim(token, invite_code):
    r = requests.post(f"{BASE_URL}/moims/join",
                      headers=_headers(token),
                      params={"inviteCode": invite_code},
                      timeout=30)
    return _ok(r, f"join:{invite_code}")

def confirm_deposit(token, moim_id, user_id):
    r = requests.post(f"{BASE_URL}/moims/{moim_id}/deposit/confirm",
                      headers=_headers(token),
                      params={"userId": user_id},
                      timeout=30)
    return _ok(r, f"confirm:{user_id}")

def create_payment(token, moim_id, merchant, amount, category=None):
    body = {"merchantName": merchant, "amount": amount}
    if category:
        body["category"] = category
    r = requests.post(f"{BASE_URL}/moims/{moim_id}/payments",
                      headers=_headers(token), json=body, timeout=30)
    return _ok(r, f"payment:{merchant}")

def settle(token, moim_id):
    r = requests.post(f"{BASE_URL}/moims/{moim_id}/settle",
                      headers=_headers(token), timeout=30)
    return _ok(r, "settle")

# ─────────────────────────────────────────────
# 서버 워밍업
# ─────────────────────────────────────────────

def warmup():
    print("🔄 Render 서버 워밍업 중 (최대 60초)...")
    for i in range(12):
        try:
            r = requests.post(f"{BASE_URL}/auth/login",
                              headers=_headers(),
                              json={"username": "_warmup_", "password": "_"},
                              timeout=10)
            if r.status_code < 500:
                print(f"  ✅ 서버 응답 확인 ({i*5}초)")
                return True
        except Exception:
            pass
        print(f"  ⏳ 대기 중... ({(i+1)*5}초)")
        time.sleep(5)
    print("  ⚠️  서버가 느릴 수 있습니다. 계속 진행합니다.")
    return False

# ─────────────────────────────────────────────
# 계정 준비
# ─────────────────────────────────────────────

def prepare_accounts():
    print("\n👤 계정 준비...")
    tokens = {}
    user_ids = {}

    all_accounts = [MAIN_USER] + EXTRA_ACCOUNTS

    for username, email, password in all_accounts:
        result = signup(username, email, password)
        if result is None:
            result = login(username, password)
        if result is None:
            print(f"  ❌ {username} 계정 준비 실패 — 스크립트를 중단합니다.")
            sys.exit(1)
        tokens[username] = result["token"]
        user_ids[username] = result["userId"]
        print(f"  ✅ {username}  (id={result['userId']}, score={result['linkScore']})")

    return tokens, user_ids

# ─────────────────────────────────────────────
# 모임 생성
# ─────────────────────────────────────────────

def seed_travel(tokens, user_ids):
    """✈️ 제주도 여행 — ACTIVE (5/5 입금, 지출 2건)"""
    print("\n✈️  제주도 여행 모임 생성...")
    main = tokens["감나빗"]
    moim = create_moim(main, {
        "title": "제주도 여행",
        "description": "5월 연휴 제주도 2박 3일! 숙소·렌트카 회비 모음",
        "emoji": "✈️",
        "targetParticipantCount": 5,
        "depositPerPerson": 100000,
        "bufferRate": 0.05,
        "refundBank": "토스뱅크",
        "refundAccountNumber": "1000-3948-2947",
    })
    if not moim:
        return
    moim_id, code = moim["id"], moim["inviteCode"]
    print(f"  초대코드: {code}  |  모임ID: {moim_id}")

    for name in ["dm_minsu", "dm_sora", "dm_hyunwoo", "dm_seoyeon"]:
        join_moim(tokens[name], code)
    print("  4명 참가 완료")

    for uid in [user_ids[n] for n in ["감나빗", "dm_minsu", "dm_sora", "dm_hyunwoo", "dm_seoyeon"]]:
        confirm_deposit(main, moim_id, uid)
    print("  5/5 입금 확인 → ACTIVE")

    create_payment(main, moim_id, "제주 감귤 펜션",  250000, "숙박")
    create_payment(main, moim_id, "제주렌터카",      120000, "교통")
    print("  지출 2건 생성 (총 370,000원)")


def seed_dinner(tokens, user_ids):
    """🍽️ 팀 회식 — OPEN (2/5 입금)"""
    print("\n🍽️  팀 회식 모임 생성...")
    main = tokens["감나빗"]
    moim = create_moim(main, {
        "title": "팀 회식",
        "description": "이번 달 팀 회식 회비 모음 🍻",
        "emoji": "🍽️",
        "targetParticipantCount": 5,
        "depositPerPerson": 40000,
        "bufferRate": 0.0,
        "refundBank": "토스뱅크",
        "refundAccountNumber": "1000-3948-2947",
    })
    if not moim:
        return
    moim_id, code = moim["id"], moim["inviteCode"]
    print(f"  초대코드: {code}  |  모임ID: {moim_id}")

    for name in ["dm_minsu", "dm_sora", "dm_hyunwoo", "dm_seoyeon"]:
        join_moim(tokens[name], code)
    print("  4명 참가 완료")

    confirm_deposit(main, moim_id, user_ids["감나빗"])
    confirm_deposit(main, moim_id, user_ids["dm_minsu"])
    print("  2/5 입금 확인 → OPEN 유지")


def seed_graduation(tokens, user_ids):
    """🎓 졸업 파티 — CLOSED (정산 완료)"""
    print("\n🎓  졸업 파티 모임 생성...")
    main = tokens["감나빗"]
    moim = create_moim(main, {
        "title": "졸업 파티",
        "description": "우리 모두의 졸업을 축하합니다 🥂",
        "emoji": "🎓",
        "targetParticipantCount": 5,
        "depositPerPerson": 50000,
        "bufferRate": 0.05,
        "refundBank": "토스뱅크",
        "refundAccountNumber": "1000-3948-2947",
    })
    if not moim:
        return
    moim_id, code = moim["id"], moim["inviteCode"]
    print(f"  초대코드: {code}  |  모임ID: {moim_id}")

    for name in ["dm_minsu", "dm_sora", "dm_hyunwoo", "dm_seoyeon"]:
        join_moim(tokens[name], code)

    for uid in [user_ids[n] for n in ["감나빗", "dm_minsu", "dm_sora", "dm_hyunwoo", "dm_seoyeon"]]:
        confirm_deposit(main, moim_id, uid)
    print("  5/5 입금 확인 → ACTIVE")

    create_payment(main, moim_id, "강남 파티룸",   150000, "장소")
    create_payment(main, moim_id, "케이크 & 음식",  72000, "식비")
    print("  지출 2건 생성 (총 222,000원)")

    result = settle(main, moim_id)
    if result is not None:
        print("  정산 완료 → CLOSED")


def seed_study(tokens, user_ids):
    """💻 개발 스터디 — ACTIVE (4/4 입금, 지출 1건)"""
    print("\n💻  개발 스터디 모임 생성...")
    main = tokens["감나빗"]
    moim = create_moim(main, {
        "title": "개발 스터디",
        "description": "Flutter & Spring 주간 스터디 공간 대여비",
        "emoji": "💻",
        "targetParticipantCount": 4,
        "depositPerPerson": 20000,
        "bufferRate": 0.0,
        "refundBank": "토스뱅크",
        "refundAccountNumber": "1000-3948-2947",
    })
    if not moim:
        return
    moim_id, code = moim["id"], moim["inviteCode"]
    print(f"  초대코드: {code}  |  모임ID: {moim_id}")

    for name in ["dm_minsu", "dm_sora", "dm_hyunwoo"]:
        join_moim(tokens[name], code)
    print("  3명 참가 완료")

    for uid in [user_ids[n] for n in ["감나빗", "dm_minsu", "dm_sora", "dm_hyunwoo"]]:
        confirm_deposit(main, moim_id, uid)
    print("  4/4 입금 확인 → ACTIVE")

    create_payment(main, moim_id, "토즈 강남점", 60000, "장소")
    print("  지출 1건 생성 (60,000원)")


# ─────────────────────────────────────────────
# 메인
# ─────────────────────────────────────────────

def main():
    print("=" * 50)
    print("  Credit-N 데모 데이터 시드")
    print("=" * 50)

    warmup()
    tokens, user_ids = prepare_accounts()

    seed_travel(tokens, user_ids)
    seed_dinner(tokens, user_ids)
    seed_graduation(tokens, user_ids)
    seed_study(tokens, user_ids)

    print("\n" + "=" * 50)
    print("  ✅ 시드 완료!")
    print("=" * 50)
    print("\n📱 앱 로그인 정보")
    print("  아이디  : 감나빗")
    print("  비밀번호: 12345678")
    print("\n📋 생성된 모임")
    print("  ✈️  제주도 여행  — ACTIVE  (5명, 지출 370,000원)")
    print("  🍽️  팀 회식     — OPEN    (5명, 2명 입금)")
    print("  🎓  졸업 파티   — CLOSED  (5명, 정산 완료)")
    print("  💻  개발 스터디 — ACTIVE  (4명, 지출 60,000원)")


if __name__ == "__main__":
    main()
