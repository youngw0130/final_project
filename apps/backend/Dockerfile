# ── Stage 1: Build ──────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jdk-alpine AS builder
WORKDIR /app

# Gradle 래퍼 + 빌드 파일 먼저 복사 (의존성 레이어 캐싱)
COPY gradlew settings.gradle build.gradle ./
COPY gradle gradle/
RUN chmod +x gradlew && ./gradlew dependencies --no-daemon --quiet || true

# 소스 복사 후 bootJar 빌드 (테스트 제외)
COPY src src/
RUN ./gradlew bootJar --no-daemon -x test --quiet

# ── Stage 2: Run ─────────────────────────────────────────────────────────────
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

RUN addgroup -S app && adduser -S app -G app
USER app

COPY --from=builder /app/build/libs/*.jar app.jar

EXPOSE 8080
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-Djava.security.egd=file:/dev/./urandom", "-jar", "app.jar"]
