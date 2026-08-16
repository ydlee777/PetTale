# Pettale

Pettale (*Pet + Tale*) is an iPhone-first, privacy-conscious pet life diary. The V1 architecture uses a native SwiftUI client for the private pet experience and a Java/Spring Boot modular monolith for service functions; Step 0 contains foundation shells only and no product features.

## Repository structure

- `ios/` — native Swift/SwiftUI iPhone application and tests
- `backend/` — Java 21, Spring Boot, Maven, PostgreSQL, and Flyway service
- `doc/` — product, technology, architecture, and Accepted ADRs

## Prerequisites

- Xcode 26.6 with the iOS 26 SDK
- Java 21 and Maven 3.9+
- PostgreSQL 18 (a supported recent PostgreSQL release is sufficient for development)

## iOS

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ios/Pettale.xcodeproj -scheme Pettale \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ios/Pettale.xcodeproj -scheme Pettale \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Open `ios/Pettale.xcodeproj` in Xcode to run the app in an iPhone simulator. The deployment target is iOS 26.0 because the selected Apple `SpeechAnalyzer` API is available starting in iOS 26.0.

## Backend

Copy `.env.example` values into your shell or secret manager; do not commit a populated `.env` file. Create the configured development database first, then run:

```sh
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
export PETTALE_DB_URL=jdbc:postgresql://localhost:5432/pettale
export PETTALE_DB_USERNAME=pettale
export PETTALE_DB_PASSWORD='your-local-password'
export PETTALE_APPLE_AUDIENCE='com.pettale.app'
export PETTALE_SESSION_SIGNING_KEY='base64-of-at-least-32-random-bytes'
export PETTALE_SESSION_LIFETIME='P30D'
# Local QA override; the checked-in server default remains 25.
export PETTALE_AI_MONTHLY_REQUEST_LIMIT='1000'
export PETTALE_EXTRACTION_MODEL='gpt-5-mini'
export PETTALE_OPENAI_API_KEY='your-server-only-development-key'
export PETTALE_OPENAI_TIMEOUT='PT30S'
export PETTALE_AI_RESERVATION_TIMEOUT='PT2M'
mvn -f backend/pom.xml spring-boot:run
curl http://localhost:8080/actuator/health
```

Configuration is supplied by `PETTALE_DB_URL`, `PETTALE_DB_USERNAME`, and `PETTALE_DB_PASSWORD`. Tests and packaging:

```sh
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home mvn -f backend/pom.xml test
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home mvn -f backend/pom.xml verify
```

Sign in with Apple is optional for local pet history and is used only to create a backend service session. See [`doc/AUTHENTICATION.md`](doc/AUTHENTICATION.md) for the verification flow, session lifecycle, environment variables, and Apple Developer setup.

The authenticated AI gateway reserves usage before calling OpenAI and returns validated transient event drafts without storing pet history. See [`doc/AI_GATEWAY.md`](doc/AI_GATEWAY.md) for quota, concurrency, privacy, and provider semantics, and [`doc/OPENAI_BENCHMARK.md`](doc/OPENAI_BENCHMARK.md) for the manual real-provider validation procedure.
