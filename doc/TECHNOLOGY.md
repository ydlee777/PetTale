# Pettale — Technology Baseline

**Status:** V1 Baseline  
**Purpose:** Technology reference for developers and Codex.

## 1. Technology Stack

| Area | V1 Decision |
|---|---|
| Client | iPhone / iOS |
| Language | Swift |
| UI | SwiftUI |
| IDE | Xcode |
| Minimum iOS | Must support Apple's SpeechAnalyzer-based implementation |
| Concurrency | Swift Concurrency (`async/await`) |
| Local persistence | SwiftData |
| Private sync | CloudKit / iCloud |
| Audio | AVFoundation |
| STT | Apple Speech framework / SpeechAnalyzer |
| Photos | PhotosUI / PhotosPicker |
| Charts | Swift Charts |
| Subscription | StoreKit 2 |
| Identity | Sign in with Apple |
| Networking | Foundation / URLSession |
| Backend | Java 21 + Spring Boot |
| Security | Spring Security |
| Persistence | Spring Data JPA |
| Service DB | PostgreSQL |
| DB migrations | Flyway |
| API | HTTPS REST / JSON |
| AI | OpenAI API |
| Initial AI candidate | GPT-5 mini; benchmark before production |
| AI response | Structured Outputs / JSON Schema |
| Localization | English + Korean |

## 2. Minimum iOS Policy
The deployment target must support the selected **SpeechAnalyzer** implementation.

Do not build a complex dual-STT architecture solely to support older iOS versions in V1. Before implementation, verify the exact minimum version against the current Xcode/Apple SDK and record it in the project/ADR.

## 3. Apple-Native First
Prefer Apple-native frameworks. Avoid third-party dependencies unless they solve a concrete requirement that native frameworks cannot adequately satisfy.

## 4. Speech-to-Text
Primary path:

**Microphone → AVFoundation → Apple SpeechAnalyzer → Transcript**

Raw audio should not normally be uploaded to Pettale/OpenAI.

Benefits:
- Lower recurring cost
- Better privacy
- Lower bandwidth
- Simpler backend

English and Korean recognition quality must be tested on real devices. A cloud transcription fallback is a later decision only if needed.

## 5. AI
All OpenAI calls pass through the Pettale backend. Never embed private AI API keys in the iOS app.

AI responsibilities:
- Extraction
- Classification
- Diary generation
- Weekly/monthly narrative summaries

Start extraction benchmarking with **GPT-5 mini**, but keep models server-configurable, e.g.:
- `PETTALE_EXTRACTION_MODEL`
- `PETTALE_SUMMARY_MODEL`

Use versioned Structured Outputs / JSON Schema for extraction.

## 6. Backend
Use a simple **modular monolith**:
- Java 21
- Spring Boot
- Spring Security
- Spring Data JPA
- PostgreSQL
- Flyway
- REST/JSON

Spring Boot is more capable than the initial service requires, but provides a mature, familiar and testable foundation. Keep deployment operationally simple.

## 7. Explicitly Not Required for V1
Do not introduce without a demonstrated need:
- Kafka
- Redis
- Kubernetes
- Microservices
- GraphQL
- Vector database
- Elasticsearch
- Event streaming infrastructure
- Cross-platform UI framework

## 8. Subscription
Use StoreKit 2 for:
- 30-day trial
- Monthly Premium
- Annual Premium
- Entitlement/status handling
- Free/Archive Mode

Use backend verification/status where required to enforce trustworthy AI access and quotas.

## 9. Advertising
Design an `AdService`/policy boundary but do not initially integrate an ad SDK.

Initial provider:
`AdService → NoAdProvider`

If Free Mode ads are activated later, select a provider after reviewing privacy, consent, ATT/App Store requirements, revenue, and UX. Trial/Premium remain ad-free.

## 10. Deterministic Computation
Use Swift/backend code—not an LLM—for statistics, counts, filtering, sorting, dates, quota arithmetic, and trend calculations.

## 11. Android Readiness
Do not use Flutter/React Native merely for future Android.

Future Android may use Kotlin + Jetpack Compose. Shared boundaries are:
- REST API
- Versioned schemas
- Canonical codes
- Business rules

## 12. Development Environment
iOS:
- macOS
- Xcode
- Swift
- iPhone Simulator
- Real iPhone testing for microphone, SpeechAnalyzer, iCloud, StoreKit

Backend:
- Java 21
- Spring Boot
- PostgreSQL
- Flyway
- Automated unit/integration tests

Pin exact tool versions when repositories are initialized.

## 13. Codex Rules
1. Inspect existing project and ADRs first.
2. Implement small independently testable steps.
3. Prefer Apple-native frameworks.
4. Never expose server secrets in the app.
5. Keep AI models server-configurable.
6. Use deterministic code for calculations.
7. Preserve canonical codes independently of UI language.
8. Add appropriate automated tests.
9. Run Xcode/backend builds and tests after relevant changes.
10. Identify migration impact before persistence changes.
11. Discuss long-term architecture changes before implementation.
