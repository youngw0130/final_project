#!/usr/bin/env python3
"""
크레딧-N | Figma 임포트용 HTML 빌드 스크립트
--------------------------------------------
styles.css를 각 HTML 파일에 인라인으로 통합하여
html.to.design 플러그인에서 바로 사용 가능한
자급자족(standalone) HTML 파일을 생성합니다.

사용법:
  python3 build_figma.py

결과:
  figma/ 폴더 안에 6개의 standalone HTML 파일 생성
"""

import os
import re

# ─────────────────────────────────────────────
# 1. 설정
# ─────────────────────────────────────────────
BASE_DIR   = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(BASE_DIR, "figma")
CSS_FILE   = os.path.join(BASE_DIR, "styles.css")

SCREENS = [
    ("index.html",               "01_메인_대시보드"),
    ("create-group.html",        "02_모임_생성"),
    ("escrow-detail.html",       "03_에스크로_상세"),
    ("qr-payment.html",          "04_QR_결제"),
    ("settlement-report.html",   "05_정산_리포트"),
    ("link-score-insights.html", "06_링크스코어_분석"),
]

# ─────────────────────────────────────────────
# 2. styles.css 읽기
# ─────────────────────────────────────────────
with open(CSS_FILE, "r", encoding="utf-8") as f:
    css_content = f.read()

INLINE_STYLE_TAG = f"<style>\n{css_content}\n</style>"

# ─────────────────────────────────────────────
# 3. 출력 폴더 생성
# ─────────────────────────────────────────────
os.makedirs(OUTPUT_DIR, exist_ok=True)

# ─────────────────────────────────────────────
# 4. 각 HTML 처리
# ─────────────────────────────────────────────
results = []

for src_name, label in SCREENS:
    src_path = os.path.join(BASE_DIR, src_name)

    if not os.path.exists(src_path):
        print(f"  ⚠️  파일 없음 → 건너뜀: {src_name}")
        continue

    with open(src_path, "r", encoding="utf-8") as f:
        html = f.read()

    # styles.css 링크를 인라인 <style>로 교체
    html = re.sub(
        r'<link\s+rel=["\']stylesheet["\']\s+href=["\']styles\.css["\']\s*/?>',
        INLINE_STYLE_TAG,
        html
    )

    # 출력 파일명: 01_메인_대시보드.html
    out_name = f"{label}.html"
    out_path = os.path.join(OUTPUT_DIR, out_name)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write(html)

    size_kb = os.path.getsize(out_path) / 1024
    results.append((label, out_name, size_kb))
    print(f"  ✅  {out_name}  ({size_kb:.0f} KB)")

# ─────────────────────────────────────────────
# 5. 결과 요약
# ─────────────────────────────────────────────
print()
print("=" * 58)
print("  🎉  빌드 완료!  figma/ 폴더를 확인하세요")
print("=" * 58)
print()
print("  📌  html.to.design 플러그인 사용법")
print()
print("  [방법 A] HTML 붙여넣기 (Paste HTML)")
print("  ① figma/ 폴더의 HTML 파일을 텍스트 편집기로 열기")
print("  ② 전체 선택(Cmd+A) → 복사(Cmd+C)")
print("  ③ Figma → 플러그인 → html.to.design → 'Paste HTML' 탭")
print("  ④ 붙여넣기 → Import 클릭")
print()
print("  [방법 B] 로컬 서버 URL (권장 — 더 정확한 렌더링)")
print("  ① 터미널에서: bash start.sh")
print("  ② Figma Desktop → html.to.design → 'URL' 탭")
print("  ③ 아래 URL을 차례로 입력하여 임포트")
print()
for label, _, _ in results:
    name = label.split("_", 1)[1].replace("_", " ")
    url_name = next(s for s, l in SCREENS if l == label)
    print(f"     http://localhost:3000/{url_name}  ({name})")
print()
