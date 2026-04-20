# 크레딧-N (Credit-N)

모임 회비를 안전하게 관리하는 에스크로 기반 결제 서비스.

---

## 📂 프로젝트 구조

```
final-project/
├── apps/                       # 실제 애플리케이션
│   ├── backend/                # Spring Boot API 서버
│   └── mobile/                 # Flutter 모바일 앱 (예정)
│
├── design/                     # 디자인 산출물
│   ├── prototypes/             # HTML 화면 시안 (Figma 임포트용)
│   │   ├── 01-dashboard.html
│   │   ├── 02-create-group.html
│   │   ├── 03-escrow-detail.html
│   │   ├── 04-qr-payment.html
│   │   ├── 05-settlement-report.html
│   │   ├── 06-link-score-insights.html
│   │   └── all-screens.html
│   ├── assets/                 # 공통 스타일/이미지
│   │   └── styles.css
│   └── figma/                  # Figma 임포트용 한글 백업본
│
├── scripts/                    # 자동화 스크립트
│   ├── start-prototypes.sh     # 디자인 시안 로컬 서버
│   └── build_figma.py
│
├── docs/                       # 기획/설계 문서
│
├── .env.example                # 환경변수 템플릿 (실제 값은 .env에)
└── README.md
```

---

## 🚀 실행 방법

### 1. 디자인 프로토타입 (HTML 시안)

Figma에 임포트하거나 브라우저에서 화면 확인용입니다.

```bash
bash scripts/start-prototypes.sh
```

서버가 뜨면 [http://localhost:3000/prototypes/01-dashboard.html](http://localhost:3000/prototypes/01-dashboard.html) 등으로 접근.

### 2. 백엔드 (Spring Boot)

```bash
cd apps/backend
./gradlew bootRun
```

환경변수 설정 필요:
```bash
cp .env.example .env
# .env 파일을 열어 실제 PortOne 키 입력
```

### 3. 모바일 앱 (Flutter, 예정)

```bash
cd apps/mobile
flutter create . --org com.creditn --project-name credit_n
flutter run
```

---

## 🔐 환경변수

`.env` 파일에 다음 키들이 필요합니다 (자세한 내용은 `.env.example` 참고):

| 키 | 설명 |
|---|---|
| `PORTONE_STORE_ID` | PortOne 콘솔에서 발급받은 Store ID |
| `PORTONE_API_SECRET` | PortOne V2 API Secret |

⚠️ `.env` 파일은 절대 커밋하지 마세요. `.gitignore`에 등록되어 있습니다.

---

## 🛠 기술 스택

- **Backend**: Spring Boot, JPA, MySQL
- **Mobile**: Flutter (예정)
- **결제**: PortOne V2
- **디자인**: Figma + html.to.design 플러그인
