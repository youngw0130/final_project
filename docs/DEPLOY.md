# 크레딧-N 배포 가이드 (Koyeb + Neon)

> **완전 무료** — 신용카드 불필요 · 기간 제한 없음

---

## 구성

| 역할 | 서비스 | 비용 |
|------|--------|------|
| 백엔드 API | Koyeb (free web service) | 무료 |
| DB | Neon.tech (PostgreSQL) | 무료 |
| Flutter 웹 | Netlify / Vercel (drag & drop) | 무료 |

---

## STEP 1 — Neon.tech PostgreSQL 생성

1. [neon.tech](https://neon.tech) → **GitHub으로 로그인**
2. **New Project** 클릭
   - Project name: `creditn`
   - PostgreSQL version: 16
   - Region: AWS / US East (또는 가장 가까운 곳)
3. 생성 완료 후 **Connection string** 복사
   - 형식: `postgresql://user:password@ep-xxx.us-east-2.aws.neon.tech/neondb?sslmode=require`
4. 이 URL에 `jdbc:` 를 앞에 붙여 저장해 두기
   - 최종 형식: `jdbc:postgresql://ep-xxx.us-east-2.aws.neon.tech/neondb?sslmode=require`

---

## STEP 2 — Koyeb 백엔드 배포

1. [koyeb.com](https://koyeb.com) → **GitHub으로 로그인**

2. 대시보드 → **Create Service** → **Web Service**

3. **Deployment method**: GitHub
   - Repository: `youngw0130/final_project`
   - Branch: `main`
   - **Root directory**: `apps/backend`
   - **Build type**: Dockerfile (자동 감지됨)

4. **Instance type**: `free` (0.1 vCPU, 512MB RAM)

5. **Environment variables** 아래 5개 입력:

   | Key | Value |
   |-----|-------|
   | `SPRING_PROFILES_ACTIVE` | `prod` |
   | `SPRING_DATASOURCE_URL` | `jdbc:postgresql://ep-xxx...neon.tech/neondb?sslmode=require` |
   | `SPRING_DATASOURCE_USERNAME` | Neon에서 복사한 username |
   | `SPRING_DATASOURCE_PASSWORD` | Neon에서 복사한 password |
   | `JWT_SECRET` | 32자 이상 랜덤 문자열 (예: `creditn-jwt-secret-key-2026-prod-abc`) |

6. **Port**: `8080`
7. **Health check path**: `/actuator/health`
8. **Deploy** 클릭

9. 배포 완료 후 URL 확인 (예: `https://creditn-backend-xxxx.koyeb.app`)
   - 헬스체크: `https://creditn-backend-xxxx.koyeb.app/actuator/health` → `{"status":"UP"}`

---

## STEP 3 — Flutter 웹 배포 (Netlify)

빌드 결과물이 이미 `apps/mobile/build/web/` 에 있습니다.

1. [app.netlify.com](https://app.netlify.com) → **GitHub으로 로그인**
2. **Add new site** → **Deploy manually**
3. `apps/mobile/build/web/` 폴더를 **드래그 앤 드롭**
4. 배포 완료 → URL 자동 생성 (예: `https://creditn-app.netlify.app`)

> 백엔드 URL이 바뀌었다면 Flutter를 다시 빌드해야 합니다:
> ```bash
> cd apps/mobile
> flutter build web \
>   --dart-define=API_BASE_URL=https://creditn-backend-xxxx.koyeb.app/api \
>   --release
> ```
> 이후 `build/web/` 폴더를 Netlify에 다시 드롭.

---

## STEP 4 — Android APK

빌드된 APK: `apps/mobile/build/app/outputs/flutter-apk/app-release.apk` (51.8MB)

실기기에 직접 설치하거나, Google Drive / 노션 등에 업로드해서 공유 가능.

---

## 시드 데이터 (자동)

첫 부팅 시 DB가 비어 있으면 테스트 계정 5명 + 모임 4개가 자동 생성됩니다.

| 아이디 | 비밀번호 |
|--------|----------|
| `minjun` | `test1234` |
| `sura` | `test1234` |
| `jiwon` | `test1234` |
| `hyunwoo` | `test1234` |
| `yuna` | `test1234` |

---

## 트러블슈팅

| 증상 | 원인 | 해결 |
|------|------|------|
| 첫 요청이 느림 (10~20초) | Koyeb free 콜드스타트 | 정상 동작, 두 번째부터 빠름 |
| DB 연결 실패 | Neon URL에 `sslmode=require` 누락 | URL 끝에 `?sslmode=require` 추가 |
| 401 Unauthorized | JWT_SECRET 불일치 | Koyeb 환경변수 확인 |
| 앱에서 API 연결 안 됨 | Flutter API_BASE_URL이 localhost | `dart-define=API_BASE_URL=...` 으로 재빌드 |
