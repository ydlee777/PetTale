# Pettale — V1 Architecture Baseline

**Status:** V1 Baseline  
**Purpose:** Define system boundaries, data ownership, runtime flow, and implementation rules.

## 1. Goals
Pettale V1 should be simple, fast, privacy-preserving, low-cost, native to iPhone, and maintainable with AI coding agents.

## 2. High-Level Architecture

```text
                    Pettale iOS
             Swift / SwiftUI / SwiftData
                        |
       +----------------+----------------+
       |                |                |
 Apple Speech      CloudKit/iCloud    StoreKit 2
 SpeechAnalyzer    Private Pet Data   Subscription
       |
       | transcript
       v
                 Pettale Backend
              Java 21 / Spring Boot
                Modular Monolith
                        |
                 +------+------+
                 |             |
             PostgreSQL     OpenAI API
           Service Data     AI Processing
              Only
```

## 3. iOS Responsibilities
The app owns the pet experience and private pet history:
- Pet profiles
- Voice recording and STT
- Transcript review
- AI request initiation
- AI result review/correction
- Diary/timeline
- Structured events/measurements
- Photos
- Statistics/charts
- Local persistence
- iCloud synchronization
- Subscription UI/state
- Free/Premium access
- Ads presentation if activated later

## 4. Private Pet Data Boundary
Private pet data belongs in **SwiftData + private iCloud/CloudKit**:
- Pets
- Diary entries
- Original transcripts
- Events
- Measurements
- Health/medication/vet history
- Photos/attachments

**Rule:** The Pettale backend is not the permanent source of truth for the user's private pet diary.

Changing iPhone should not cause loss of history when the user's Apple/iCloud environment supports restoration/synchronization.

## 5. Backend Responsibilities
The backend handles service functions:
- Service identity
- Sign in with Apple integration
- Account status
- Trial/subscription status
- Subscription verification where required
- AI usage accounting
- Quotas/rate limiting
- AI gateway
- Server-side model configuration
- Minimal operational/security logging

It may transiently process transcript text/compact context required for an AI request. Retention should be minimized.

## 6. PostgreSQL Boundary
PostgreSQL stores service-management data such as:
- users / identities
- subscription status
- trial status
- AI usage/quota
- operational/security records

It does **not** become a duplicate permanent pet-history database in V1.

## 7. Voice Record Flow

```text
Record
  ↓
AVFoundation temporary audio
  ↓
Apple SpeechAnalyzer
  ↓
Transcript
  ↓
Delete temporary audio after successful transcription
  ↓
HTTPS → Pettale Backend
  ↓
Check identity / subscription / AI quota
  ↓
Configured OpenAI model
  ↓
Structured event JSON
  ↓
iPhone review/correction
  ↓
SwiftData save
  ↓
CloudKit/iCloud sync
  ↓
Diary/statistics refresh
```

## 8. AI Security Boundary

```text
iPhone
   | HTTPS
   v
Pettale Backend
   | server-only credential
   v
OpenAI API
```

The iPhone never contains the private OpenAI API key.

Backend AI gateway enforces authentication, subscription access, usage limits, rate limits, model configuration, and schema/version policy.

AI is not the system of record.

## 9. Event Model
One note may create multiple events while preserving original context.

Canonical categories:
- FOOD
- WEIGHT
- HEALTH
- MEDICATION
- ACTIVITY
- BEHAVIOR
- SLEEP
- GROOMING
- VET
- EVENT
- OTHER

Display labels are localized separately.

The schema should be versionable and evolvable without over-engineering V1.

## 10. Statistics
Statistics are deterministic:

```text
SwiftData events/measurements
          ↓
    Swift business logic
          ↓
 counts / averages / trends
          ↓
      Swift Charts
```

Weekly/monthly AI summaries may receive compact computed statistics plus selected structured events.

## 11. Photos
V1 photos are attachments:
- Selected via PhotosPicker
- Stored/synchronized in the user's private data boundary
- Not automatically uploaded for AI analysis
- AI vision requires a later explicit feature decision

## 12. Subscription / Feature Policy

```text
StoreKit 2
   ↓
SubscriptionService
   ↓
FeatureAccessPolicy
   ├── Trial
   ├── Free
   └── Premium
          ↓
   AI quota / summaries / ads
```

Backend and client responsibilities should be clearly separated. Server-side controls protect AI cost and service abuse.

## 13. Advertising Boundary

```text
FeatureAccessPolicy
        ↓
    AdService
        ↓
  NoAdProvider (initial V1)
        ↓ later, if approved
  Advertising Provider
```

Ads are allowed only in Free Mode if activated. Trial and Premium are ad-free.

No ad SDK is required until advertising is explicitly enabled.

## 14. Backend Structure
Use one Spring Boot modular monolith, not microservices.

Suggested logical modules:
- identity
- subscription
- usage
- ai
- operational/security

Keep module boundaries clear without unnecessary infrastructure.

## 15. Future Android
Future Android may be a separate native Kotlin/Jetpack Compose app.

Shared platform-independent contracts:
- Pettale REST API
- AI/event JSON schemas
- Canonical codes
- Business rules

Do not compromise iOS V1 to share UI code.

## 16. Architecture Rules for Codex
1. Inspect existing code and ADRs before changing architecture.
2. Reuse existing functionality.
3. Keep private pet history out of the Pettale backend unless an ADR explicitly changes the rule.
4. Never put server API secrets in the iOS app.
5. Keep raw audio temporary by default.
6. Keep AI model selection server-configurable.
7. Use deterministic logic for calculations.
8. Prefer Apple-native frameworks.
9. Do not introduce Kafka, Redis, Kubernetes, microservices, vector DB, or other infrastructure without a concrete approved requirement.
10. Consider schema migration and backward compatibility before persistence changes.
11. Add tests and verify builds after each small implementation step.
12. Record consequential architectural changes in ADRs.
