# ADR-003: Backend Architecture and AI Boundary

- **Status:** Accepted
- **Date:** 2026-08-16
- **Decision Owners:** Pettale
- **Applies To:** Pettale V1

## Context

Pettale needs a server-side component for functions that should not live exclusively on the iPhone.

These include:

- Pettale service identity
- Sign in with Apple integration
- Trial/subscription status
- Subscription verification where required
- AI usage tracking
- AI quotas and rate limiting
- AI gateway
- Server-side AI model configuration
- Minimal operational/security data

The backend does not need to store the user's complete private pet diary.

Pettale is initially a small commercial consumer application, so the backend should remain operationally simple and cost-conscious.

External AI API credentials must never be embedded in the iOS application.

## Decision

Pettale V1 backend will use:

- **Java 21**
- **Spring Boot**
- **Spring Security**
- **Spring Data JPA**
- **PostgreSQL**
- **Flyway**
- **HTTPS REST / JSON**

The backend will be implemented as a **modular monolith**.

It will not be split into microservices for V1.

PostgreSQL will contain Pettale service-management data such as:

- User/service identity
- Sign in with Apple identity references
- Trial status
- Subscription status/verification data
- AI usage
- AI quota/rate-limit information
- Required operational/security records

Private pet history remains governed by ADR-002.

## AI Gateway

All external AI calls requiring private server credentials will pass through the Pettale backend.

Architecture:

```text
Pettale iOS
     |
     | HTTPS
     v
Pettale Backend
     |
     | Server-only AI credential
     v
OpenAI API
```

The OpenAI API key or equivalent private provider credential must never be embedded in the iOS application.

## AI Model Policy

OpenAI is the initial AI provider.

GPT-5 mini is the initial candidate for extraction/classification benchmarking, not a permanently hard-coded architectural dependency.

Model selection must be server-configurable, for example:

- `PETTALE_EXTRACTION_MODEL`
- `PETTALE_SUMMARY_MODEL`

This allows Pettale to change models based on:

- Quality
- Latency
- Price
- Reliability
- Provider/model evolution

without requiring an App Store release.

## AI Responsibilities

LLMs may be used for:

- Natural-language understanding
- Event extraction
- Event classification
- Diary generation
- Weekly/monthly narrative summaries
- Future approved natural-language historical queries

LLMs must not be used for deterministic operations that application/backend code can perform reliably, including:

- Weight averages
- Weight changes
- Counts
- Date filtering
- Medication counts
- Trend calculations
- Usage quota arithmetic

## Structured Output

AI extraction/classification must use a versioned structured contract, preferably Structured Outputs / JSON Schema where supported.

One transcript may generate multiple events.

Canonical category/event codes must be independent of the user's display language.

The user must be able to review/correct extracted information before final save.

## Backend Module Direction

Suggested logical modules:

```text
identity
subscription
usage
ai
operational/security
```

These are logical module boundaries inside one Spring Boot application, not separately deployed services.

## Technologies Not Required for V1

Do not introduce without a concrete approved requirement:

- Kafka
- Redis
- Kubernetes
- Microservices
- GraphQL
- Vector database
- Elasticsearch
- Event-streaming infrastructure
- Separate enterprise API gateway

The absence of these technologies is intentional.

## Rationale

Spring Boot and PostgreSQL provide a mature and familiar foundation for authentication, transactional service data, migrations, testing, and API development.

Although Spring Boot is more capable than the initial backend requires, using a familiar stack reduces development risk and does not justify introducing another backend ecosystem merely to minimize framework size.

A modular monolith provides sufficient separation without distributed-system complexity.

## Consequences

### Positive

- Mature backend ecosystem.
- Strong PostgreSQL/Flyway support.
- Straightforward automated testing.
- Central protection of AI credentials.
- Central AI cost/quota control.
- Model changes do not require an iOS release.
- Clean future API boundary for Android.

### Negative / Trade-offs

- Spring Boot has a larger runtime footprint than some lightweight alternatives.
- Pettale must operate a backend even though private diary storage is primarily Apple-side.
- Subscription and AI gateway availability become service dependencies for premium AI operations.

## Security and Privacy Rules

1. Never ship private AI/provider credentials in the client.
2. Use HTTPS for client/backend communication.
3. Authenticate service operations appropriately.
4. Minimize logging of transcript/private content.
5. Do not make PostgreSQL a duplicate pet-history store.
6. Enforce AI quotas/rate limits server-side.
7. Treat model/provider configuration as server-side operational configuration.
8. Keep sensitive operational secrets outside source control.

## Revisit When

Revisit this ADR if:

- Backend scale demonstrates a concrete need for architectural decomposition.
- A different AI provider/model materially improves economics or quality.
- Android/cross-platform requirements alter service responsibilities.
- A feature requires server-side pet history and ADR-002 is reconsidered.
- Operational evidence demonstrates a need for Redis, messaging, or other infrastructure.
