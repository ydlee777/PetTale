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
mvn -f backend/pom.xml spring-boot:run
curl http://localhost:8080/actuator/health
```

Configuration is supplied by `PETTALE_DB_URL`, `PETTALE_DB_USERNAME`, and `PETTALE_DB_PASSWORD`. Tests and packaging:

```sh
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home mvn -f backend/pom.xml test
JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home mvn -f backend/pom.xml verify
```

