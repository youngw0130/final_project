#!/bin/bash
# 크레딧-N 백엔드 실행 (Python으로 .env 파싱)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/apps/backend"
ENV_FILE="$ROOT_DIR/.env"
TEMP_PROPS="/tmp/creditn-runtime.properties"
PORT=8080

# Python으로 .env 파싱 → properties 파일 생성
python3 - "$ENV_FILE" "$TEMP_PROPS" << 'PYEOF'
import sys, os

env_file, out_file = sys.argv[1], sys.argv[2]
env = {}
with open(env_file, encoding="utf-8-sig") as f:
    for line in f:
        line = line.rstrip("\r\n").strip()
        if not line or line.startswith("#"):
            continue
        line = line.removeprefix("export").strip()
        if "=" not in line:
            continue
        k, _, v = line.partition("=")
        env[k.strip()] = v.strip().strip('"').strip("'")

db_url = env.get("SPRING_DATASOURCE_URL", "")
if not db_url:
    print(f"❌  SPRING_DATASOURCE_URL 미설정. 발견된 키: {list(env.keys())}")
    sys.exit(1)

print(f"DB: {db_url[:60]}...")

with open(out_file, "w") as f:
    def w(k, v, default=""):
        f.write(f"{k}={env.get(v, default)}\n")
    f.write(f"spring.datasource.url={db_url}\n")
    w("spring.datasource.username", "SPRING_DATASOURCE_USERNAME")
    w("spring.datasource.password", "SPRING_DATASOURCE_PASSWORD")
    f.write("spring.datasource.driver-class-name=org.postgresql.Driver\n")
    w("jwt.secret", "JWT_SECRET", "credit-n-secret-key-for-jwt-token-signing-must-be-long-enough")
    w("portone.store-id", "PORTONE_STORE_ID", "demo-store-id")
    w("portone.api-secret", "PORTONE_API_SECRET", "demo-secret")
    w("portone.channel-key", "PORTONE_CHANNEL_KEY", "demo-channel-key")
    w("portone.webhook-secret", "PORTONE_WEBHOOK_SECRET", "demo-webhook-secret")
print("Properties 작성 완료")
PYEOF

# 포트 정리
lsof -ti :$PORT 2>/dev/null | xargs kill -9 2>/dev/null || true

cd "$BACKEND_DIR"

JAR=$(ls build/libs/credit-n-*.jar 2>/dev/null | grep -v plain | head -1)
if [ -z "$JAR" ]; then
  echo "📦  bootJar 빌드..."
  ./gradlew bootJar -x test --quiet
  JAR=$(ls build/libs/credit-n-*.jar | grep -v plain | head -1)
fi

echo "▶  Starting $JAR"
exec java -Xmx512m \
  -jar "$JAR" \
  --spring.profiles.active=prod \
  --spring.config.additional-location="file:$TEMP_PROPS"
