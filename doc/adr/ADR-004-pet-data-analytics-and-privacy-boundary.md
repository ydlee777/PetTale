# ADR-004 — Pet Data Analytics and Privacy Boundary

- **Status:** Proposed
- **Date:** 2026-08-17
- **Related:** PRODUCT.md, TECHNOLOGY.md, ARCHITECTURE.md, ADR-002, ADR-003

## Context

Pettale is designed as a long-term private memory of a pet's life. The current architecture separates private pet history from Pettale service-management data:

- **Private pet history:** SwiftData with Private CloudKit synchronization.
- **Pettale backend:** service identity, authentication, subscription/trial state, AI usage, limits, AI gateway, and operational data.
- The backend is not the authoritative store for Pet, PetRecord, PetEvent, transcript, photo, or diary history.

This boundary is appropriate for V1. However, aggregated data across many pets could later help Pettale improve event extraction, understand product usage, build population-level statistics, and create useful comparison/intelligence features.

The architecture should therefore preserve individual privacy without permanently preventing carefully governed analytics.

## Decision

Pettale will maintain a strict separation between **Private Pet History**, **Pettale Analytics Data**, and **Service/Operational Data**.

### 1. Private Pet History remains Apple-side authoritative data

The authoritative source for an individual pet's personal history remains the user's Apple-side private storage.

This includes:

- Pet profile and pet name
- Pet photos
- Approved voice-note transcript
- Generated diary text
- PetRecord
- PetEvent
- Weight and other measurements
- Health observations
- Medication history
- Activity and behavior history
- Veterinary history
- Other personal diary content

For V1 this remains:

**SwiftData → Private CloudKit**

The Pettale backend must not become a duplicate authoritative pet-history database merely for future analytics convenience.

### 2. Service/Operational Data may remain in the Pettale backend

The backend may store data necessary to operate the commercial service, including:

- Pettale service user identity
- Authentication-related service data
- Subscription status
- Trial status
- AI usage
- AI quotas and limits
- Provider/model/token metadata
- Operational status and safe failure categories

This data must remain separated from private pet-history content.

### 3. Future analytics data must be purpose-specific and minimized

Pettale may introduce a separate analytics data boundary when there is a concrete product or business requirement.

Instead of copying complete histories, analytics should prefer narrowly scoped structured attributes such as:

```text
species = CAT
age_band = 1-2Y
event_category = HEALTH
event_type = VOMITING
count = 1
```

when those fields are sufficient for the approved purpose.

Analytics records should avoid direct personal or pet identifiers unless an approved requirement makes linkage necessary.

### 4. Raw private content is not general analytics data

The following must not be collected into general Pettale analytics merely because it could be useful later:

- Raw voice audio
- Full transcripts
- Full diary text
- Photos
- Free-form private descriptions
- Complete pet histories
- Raw AI prompts containing private pet history
- Raw AI provider responses containing private pet history

Collection of such content for AI/product improvement requires a separately approved design, explicit purpose, appropriate user disclosure/consent where required, retention limits, and a new or amended ADR.

### 5. AI processing does not imply backend retention

Pet data may transiently pass through the Pettale backend and an approved AI provider to perform a user-requested feature.

```text
Approved transcript
        ↓
Pettale AI Gateway
        ↓
AI Provider
        ↓
Structured Event Draft
        ↓
iPhone
```

Transient processing does not authorize permanent backend storage.

The backend should continue to avoid persisting transcript, prompt, AI response body, pet name/history, or audio unless explicitly approved by a future architectural decision.

### 6. Analytics and private history must not silently merge

Future analytics must have a clearly defined boundary:

```text
Private Pet History
SwiftData + Private CloudKit
        │
        │ approved minimized analytics only
        ▼
Pettale Analytics Boundary
        │
        ▼
Aggregated Product Intelligence
```

A Pettale service account must not automatically cause the user's complete private pet history to be uploaded to Pettale servers.

### 7. Aggregation is preferred over individual-history replication

Where a product question can be answered using aggregated or derived data, Pettale should prefer that approach.

Potential future examples:

- Weight distributions by broad species/age groups
- Frequency of selected event types
- AI extraction correction rates
- Feature usage rates
- Retention and engagement metrics

These are future possibilities, not authorization to implement collection in V1.

### 8. AI training/improvement data requires a separate decision

Using user transcripts, diary text, photos, or detailed histories to improve Pettale's AI is materially different from operational analytics.

Before implementing such a dataset, Pettale must separately decide:

- Exact data collected
- Purpose
- Whether explicit opt-in is required
- De-identification approach
- Retention period
- Deletion behavior
- Provider access
- Security controls
- Training vs. evaluation use
- User-facing privacy disclosure

A new ADR or explicit amendment is required.

## V1 Implications

This ADR does **not** authorize a new analytics backend implementation now.

For current V1:

- Pet remains SwiftData/Private CloudKit data.
- PetRecord remains SwiftData/Private CloudKit data.
- PetEvent remains SwiftData/Private CloudKit data.
- Photos remain Apple-side private data.
- Approved transcript remains Apple-side private history.
- Future diary text remains Apple-side private history.
- Audio remains temporary and is deleted according to the existing lifecycle.
- PostgreSQL continues to store only approved service/operational data.
- No pet analytics table is required now.
- No Pet/PetRecord/PetEvent backend replication is required now.

Analytics implementation should be postponed until a concrete V1 or post-V1 requirement justifies it.

## Privacy Principles

Any future analytics implementation must follow:

1. **Purpose limitation** — collect data for a defined product/business purpose.
2. **Data minimization** — collect the smallest dataset that satisfies that purpose.
3. **Separation** — keep private history distinct from analytics and service-management data.
4. **No silent expansion** — do not expand collection simply because more data might be useful.
5. **Retention discipline** — define retention periods.
6. **Deletion consideration** — define behavior when a user deletes a pet or account.
7. **Transparency** — accurately disclose collected data and purpose.
8. **Security** — protect analytics and operational data appropriately.

## Consequences

### Positive

- Preserves Pettale's privacy-first architecture.
- Keeps private diary content under the user's Apple-side storage boundary.
- Avoids unnecessary backend storage and infrastructure cost in V1.
- Leaves room for future population-level product intelligence.
- Reduces collection of sensitive free-form content without a concrete use.
- Lets analytics evolve from real product needs.

### Trade-offs

- Pettale will not initially have a complete centralized dataset of pet histories.
- Some future analytics features may require new consent, schemas, APIs, and pipelines.
- Population-level intelligence cannot directly query all private CloudKit histories.
- Future analytics must deliberately define which derived data may leave the device.

These trade-offs are accepted in favor of privacy, architectural simplicity, and V1 speed.

## Rejected Alternatives

### A. Replicate all pet history to PostgreSQL now

Rejected because it duplicates the Apple-side authoritative store, increases privacy/security obligations and infrastructure complexity, and is not required to validate V1 willingness-to-use/pay.

### B. Never allow any pet-derived analytics

Rejected because it would unnecessarily prevent future product improvement and population-level intelligence where privacy-preserving aggregated data could provide meaningful value.

### C. Store raw transcripts and AI responses for future model improvement by default

Rejected because raw free-form content contains substantially more private context than normal operational analytics and requires a separate explicit decision and appropriate disclosure/consent.

## Future Decision Triggers

Revisit this ADR when Pettale proposes:

- Population-level pet statistics
- Personalized comparison against other pets
- Centralized health/event analytics
- AI extraction quality datasets using user content
- Model training/evaluation using private pet records
- Backend synchronization of Pet/PetRecord/PetEvent
- Cross-platform server-authoritative history for Android
- Data sharing with external research or commercial partners

Any such proposal must specify exact data flow, retention, privacy implications, user controls, and business value before implementation.

## Decision Summary

**Private pet history remains Apple-side and authoritative. Pettale may later collect narrowly scoped, purpose-specific, privacy-preserving analytics data, but this ADR does not authorize replication of raw pet histories or use of private content for AI training. Any broader collection requires a separate explicit architectural and privacy decision.**
