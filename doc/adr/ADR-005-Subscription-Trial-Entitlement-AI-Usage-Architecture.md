# ADR-005 --- Subscription, Trial, Entitlement and AI Usage Architecture

> **Product rename note (2026-08-18):** Pettale was renamed to Oreamy
> before release. The decision itself is unchanged; current product
> references and Apple identifiers use Oreamy.

**Status:** Accepted\
**Date:** 2026-08-17\
**Amended:** 2026-08-18\
**Decision Owners:** Oreamy\
**Scope:** iOS V1 subscription, Premium trial, free/archive access,
entitlement synchronization, and AI usage authorization

## 1. Context

Oreamy is a commercial consumer application whose core paid value is
the ability to quickly create structured pet-life records using:

**Voice → on-device Speech-to-Text → Oreamy AI extraction → Diary +
structured events → long-term pet history**

Private pet data remains in the Apple-side persistence architecture (Pet
profiles, PetRecord, original transcript, diary text, PetEvent,
weight/health history, Diary/Timeline, and derived local statistics).

Oreamy backend stores service-management data only: service identity,
authentication, AI usage, entitlement information, and
subscription/trial state.

Pet history must not be moved to the Oreamy backend merely to support
subscriptions.

## 2. Decision

Oreamy will use a three-layer authority model:

**Apple StoreKit 2 → Oreamy Backend → Oreamy iOS App**

-   **Apple** is authoritative for App Store subscription entitlement.
-   **Oreamy Backend** is authoritative for service access, trial
    state, AI allowance, and authorization of server-side AI operations.
-   **iOS App** presents products/prices, initiates purchases, restores
    purchases, observes StoreKit entitlement, synchronizes entitlement
    with the backend, and preserves local access to existing pet
    history.

The iOS client is not the final authority for paid AI access.

## 3. V1 Commercial Plans

Backend service-access states:

-   `PREMIUM_TRIAL`
-   `PREMIUM`
-   `FREE`

`FREE` also represents post-trial/post-subscription archive mode.

The iOS V1 user-facing subscription presentation contract has exactly
five states:

-   `FREE_TRIAL`
-   `FREE`
-   `PREMIUM_MONTHLY`
-   `PREMIUM_YEARLY`
-   `PREMIUM_EXPIRING`

`PREMIUM_EXPIRING` retains the current/previous paid product (Monthly or
Yearly) and its verified expiration date. StoreKit verified entitlement
and renewal information determine paid presentation state. A Oreamy
backend trial must never be presented as a paid Premium subscription.

## 4. Premium Trial

Oreamy provides **30 days of Premium access**.

The V1 Premium Trial is a **Oreamy service trial**, not an App Store
introductory subscription trial. Apple introductory offers may be
evaluated later.

## 5. Trial Start

The trial begins when the Oreamy backend creates a new `ServiceUser`.
It does not wait for the first successful AI-powered diary/event
extraction. Install, launch, Pet creation, and browsing without service
account creation do not start the trial.

For compatibility with accounts created before this decision:

-   Existing users with non-null `trial_started_at` and
    `trial_expires_at` retain those values exactly.
-   Existing users with both trial dates null are backfilled with
    `trial_started_at = service_user.created_at` and
    `trial_expires_at = service_user.created_at + 30 days`.
-   Existing accounts are never reset or extended. An account older
    than 30 days may therefore become `FREE` immediately after the
    compatibility migration.

## 6. Trial Authority

Trial state is authoritative in the Oreamy backend. It should persist
sufficient information such as `trial_started_at` and
`trial_expires_at`, or an equivalent entitlement model.

Trial state must not rely solely on UserDefaults, Keychain, installation
date, or device-local state.

## 7. Trial Eligibility

One Oreamy Premium Trial per `ServiceUser`.

Reinstalling Oreamy or changing iPhones must not create a new trial for
the same service identity.

## 8. Trial Access

During an active trial, the user receives Premium functionality subject
to server-side AI fair-use controls.

Existing private pet history remains Apple-side.

## 9. Premium Subscription Products

Initial target pricing:

-   Monthly: **US\$4.99/month**
-   Annual: **approximately US\$47.99/year**

Final storefront prices are configured in App Store Connect. Oreamy
must display StoreKit-provided localized pricing rather than hard-coded
USD prices.

## 10. StoreKit

Oreamy V1 uses **StoreKit 2** and native Apple frameworks.

StoreKit handles product loading, purchase flow, on-device transaction
verification, entitlement observation, restoration, and
subscription-status presentation.

No third-party subscription SDK is introduced for V1.

## 11. Subscription Product Structure

Monthly and annual Premium products belong to one subscription group:

-   Oreamy Premium Monthly
-   Oreamy Premium Annual

Both grant the same Premium entitlement.

The only V1 product identifiers eligible for paid Premium authority
are:

-   `com.oreamy.app.premium.monthly`
-   `com.oreamy.app.premium.annual`

The backend rejects every unknown product identifier.

## 12. Premium Entitlement

An active verified Premium subscription grants `PREMIUM` service access.

Product identifiers remain configuration constants, not user-facing
text.

During Step 8B, local verified StoreKit entitlement is authoritative
only for iOS paid-subscription presentation. It does not by itself grant
backend Premium service access. Actual Apple paid entitlement to Oreamy
backend synchronization and server-side verification are implemented
through Step 8C. Until the relevant Step 8C slice exists and verifies
Apple evidence, neither the client nor the backend may pretend that
local StoreKit state has established backend Premium authority.

## 13. Server-Side Subscription Verification

The backend must never trust client assertions such as
`{ "premium": true }`.

Apple-signed StoreKit transaction JWS is the V1 paid-entitlement
evidence. The client may forward this evidence but cannot self-assert
Premium status.

The backend verifies Apple-signed evidence using Apple's supported App
Store Server verification/library mechanisms. The approved V1 server
direction is:

-   App Store Server Library for signed-data verification;
-   App Store Server API for authoritative subscription
    reconciliation; and
-   App Store Server Notifications V2 for subscription lifecycle
    updates.

### 13.1 Account Ownership

Every new Oreamy purchase supplies:

`appAccountToken = authenticated Oreamy ServiceUser.id`

`ServiceUser.id` is a UUID. The backend requires the verified
transaction's `appAccountToken` to equal the authenticated
`ServiceUser.id`. A missing or mismatched token is rejected and cannot
grant backend Premium.

### 13.2 Transaction Ownership and Idempotency

An Apple `originalTransactionId` belongs to exactly one `ServiceUser`.
The same `originalTransactionId` cannot grant Premium to another Oreamy
account. Repeated synchronization of the same verified transaction is
idempotent and must not create duplicate subscription authority or AI
usage.

### 13.3 Tokenless Transactions

Transactions without `appAccountToken` do not automatically grant
backend Premium. Oreamy V1 does not provide an automatic legacy-claim
mechanism.

Current pre-release Xcode StoreKit and Sandbox development transactions
are test data and require no production ownership migration.

### 13.4 Entitlement Lifecycle and Precedence

Backend effective service access is resolved in this order:

1.  valid Apple-verified paid entitlement → `PREMIUM`, 300 AI
    extractions per UTC calendar month;
2.  otherwise, valid Oreamy trial → `PREMIUM_TRIAL`, 300 per month;
3.  otherwise → `FREE`, 3 per month.

Cancellation of auto-renewal does not immediately remove Premium.
Premium remains valid until Apple's verified expiration. Expired or
revoked entitlement does not grant paid Premium.

### 13.5 Apple Service Outage Policy

If the backend already holds an Apple-verified entitlement whose last
verified expiration remains in the future, a temporary Apple API outage
does not immediately downgrade the user.

The backend must never extend Premium beyond the last Apple-verified
expiration solely because Apple is unavailable.

### 13.6 Environment Policy

-   Xcode local StoreKit configuration is for local iOS UI and state
    testing only. It is not production backend Premium authority.
-   Apple Sandbox is used for backend Apple integration testing.
-   Production uses Apple's production verification environment.

Oreamy does not add production exceptions that allow Xcode-local
transactions to establish backend Premium authority.

Apple private keys and verification credentials are backend-only
secrets. They must never be embedded in iOS or committed to Git.

## 14. AI Authorization

Every server-side paid AI operation is authorized by the Oreamy
backend:

**Authenticated ServiceUser → resolve service access →
Trial/Premium/Free allowance → usage check/reservation → OpenAI**

OpenAI must not be called before access and quota authorization
succeeds.

## 15. Free / Archive Mode

When the trial expires and no active Premium subscription exists, the
user enters `FREE` mode.

Existing pet history remains available.

## 16. Permanent Access to Existing Pet History

FREE users retain access to:

-   Pet profiles
-   Pet management
-   existing Diary, diary text, and photos
-   original transcripts
-   structured events
-   Weight Trend
-   Health History
-   Record Summary
-   other deterministic local views derived from existing data

Subscription expiration, cancellation, or billing expiration must not
lock or delete existing personal pet history.

## 17. Free AI Allowance

Initial V1 policy:

**3 AI extraction operations per UTC calendar month**

Configurable, e.g.:

`OREAMY_AI_FREE_MONTHLY_REQUEST_LIMIT=3`

The value is product policy, not an architectural constant.

## 18. Premium AI Allowance

Initial V1 fair-use guard:

**300 AI extraction operations per UTC calendar month**

Configurable, e.g.:

`OREAMY_AI_PREMIUM_MONTHLY_REQUEST_LIMIT=300`

The same 300-request allowance applies to an active Oreamy Premium
Trial. Once Step 8C server entitlement synchronization exists, valid
Monthly Premium, valid Yearly Premium, and `PREMIUM_EXPIRING` before its
verified expiration use this allowance. This remains a configurable
cost/abuse guard rather than a permanent product promise.

## 19. Usage Accounting

Existing `ai_usage` remains authoritative.

One successful AI diary creation consumes one `EVENT_EXTRACTION`
operation even though the single provider response contains both
`diaryText` and structured events.

## 20. Failed AI Requests

Existing lifecycle remains:

-   `RESERVED → SUCCEEDED`
-   `RESERVED → FAILED`

Provider/system failures should not permanently consume allowance when
classified as failed under existing policy.

## 21. Development / QA Allowance

Development may override limits with configuration, e.g.:

-   `OREAMY_AI_FREE_MONTHLY_REQUEST_LIMIT=1000`
-   `OREAMY_AI_PREMIUM_MONTHLY_REQUEST_LIMIT=1000`

Do not delete usage rows, bypass authentication, or disable quota
enforcement in code.

## 22. Subscription Expiration

`PREMIUM → FREE`

Existing local data remains untouched and requires no data migration.

## 23. Subscription Cancellation

Cancellation of auto-renewal does not immediately remove Premium. Access
remains until Apple's verified entitlement expiration. The iOS paid
presentation state is `PREMIUM_EXPIRING`, retaining the Monthly or Yearly
product and verified expiration date. After expiration, presentation
falls back to backend `FREE_TRIAL` when still valid, otherwise `FREE`.

## 24. Billing Problems

Grace period and billing retry behavior follow verified Apple
subscription status. Oreamy does not invent separate billing-state
semantics.

## 25. Restore Purchases

Oreamy provides a standard **Restore Purchases** action.

Restoration refreshes verified entitlement and synchronizes service
access with the backend.

## 26. Device Replacement

Recovery paths remain separate:

-   Pet history → SwiftData/private CloudKit
-   Service identity → Sign in with Apple
-   Premium entitlement → Apple subscription entitlement/restore
-   Trial state → Oreamy backend

## 27. Authentication and Subscription

Local private history can be browsed without a functioning backend
session.

Server-side AI and subscription synchronization require authenticated
Oreamy service identity.

## 28. Offline Behavior

Backend/network outages must not block browsing:

-   Diary
-   Weight Trend
-   Health History
-   Record Summary

New server-side AI operations require connectivity.

## 29. Paywall Timing

Do not show a paywall immediately at first launch.

Appropriate conversion moments include:

-   subscription/account management
-   trial nearing expiration
-   trial expired and free AI allowance exhausted

Browsing existing history must not trigger a paywall.

## 30. Trial Expiration UX

Do not imply that user data is locked.

Communicate that Oreamy history remains available and Premium provides
more AI-powered recordings.

## 31. Free Allowance Exhaustion UX

Use product language rather than backend quota terminology.

Explain that the month's free AI recordings have been used and Premium
allows continued AI recording.

Existing history remains available.

## 32. Premium Fair-Use Limit UX

If a Premium user reaches the server-side safety limit, use a
service-limit message rather than an upgrade upsell.

## 33. Pricing Authority

App Store Connect / StoreKit is authoritative for localized subscription
pricing.

Never assume USD formatting for all users.

## 34. Subscription Data in PostgreSQL

Backend may retain only service-management data necessary for
entitlement operation, including where required:

-   ServiceUser association
-   trial start/expiration
-   subscription product
-   entitlement state
-   verified expiration
-   last synchronization timestamp
-   Apple transaction/original transaction identifiers where
    operationally required
-   verified `appAccountToken` ownership association
-   Apple environment and verification status

Minimize retained App Store data.

## 35. Privacy Boundary

Subscriptions do not change the private-data architecture.

PostgreSQL must not gain Pet, PetRecord, PetEvent, diaryText,
originalTranscript, weight history, health history, photos, or raw audio
solely because subscriptions are introduced.

## 36. App Store Transaction Privacy

Store only transaction information necessary to verify entitlement,
restore association, prevent spoofing, and maintain service access.

Do not unnecessarily log full signed transaction payloads or
credentials.

## 37. Local Subscription Cache

iOS may cache presentation-oriented entitlement state for UX continuity.

It is not authoritative for server-side AI access.

## 38. Source of Truth Summary

  -----------------------------------------------------------------------
  Concern                             Authority
  ----------------------------------- -----------------------------------
  Pet profile/history                 SwiftData + private CloudKit

  Apple subscription purchase         Apple / StoreKit

  Verified Premium entitlement        Apple evidence verified for Oreamy
                                      service

  Oreamy trial                       Oreamy backend

  AI usage count                      Oreamy backend `ai_usage`

  AI operation authorization          Oreamy backend

  Local history browsing              iOS local/private Apple data

  Localized subscription price        StoreKit

  OpenAI credentials                  Oreamy backend
  -----------------------------------------------------------------------

## 39. V1 Access Matrix

  ---------------------------------------------------------------------------
  Feature                 Premium Trial            Premium               Free
  ------------------ ------------------ ------------------ ------------------
  Existing Pet                      Yes                Yes                Yes
  profiles

  Existing Diary                    Yes                Yes                Yes

  Existing Weight                   Yes                Yes                Yes
  Trend

  Existing Health                   Yes                Yes                Yes
  History

  Existing Record                   Yes                Yes                Yes
  Summary

  Existing photos                   Yes                Yes                Yes

  Pet management                    Yes                Yes                Yes

  AI voice diary      Premium allowance  Premium allowance     Free allowance

  Initial monthly AI                300                300                  3
  allowance

  Purchase/upgrade                  Yes             Manage                Yes

  Restore purchase                  Yes                Yes                Yes
  ---------------------------------------------------------------------------

Allowance values are configurable V1 policy, not architectural
constants.

## 40. Why Not Lock Historical Records?

Oreamy's long-term value comes from years of personal pet history.

Locking existing records after subscription expiration would reduce
trust, discourage retention, and conflict with the private/local
architecture.

Subscriptions monetize ongoing AI-assisted recording and future Premium
services, not access to the user's own existing history.

## 41. Why Provide Free AI Usage?

A small FREE allowance supports continued engagement, reminds users of
Oreamy's value, creates a path back to Premium, and reduces post-trial
uninstall pressure.

The exact allowance should be revisited using real conversion,
retention, and cost data.

## 42. Consequences

### Positive

-   Clear authority boundaries between Apple, backend, and local private
    data.
-   Subscription expiration cannot strand user history.
-   Trial cannot be reset by reinstalling.
-   Server-side AI cost remains controllable.
-   Free users retain a reason to keep Oreamy installed.
-   StoreKit remains the source of localized pricing and purchase state.
-   Policy values can evolve without redesigning the architecture.

### Negative / Trade-offs

-   Backend must maintain trial and entitlement state.
-   App Store entitlement synchronization adds backend complexity.
-   Offline presentation state and backend authority can temporarily
    differ.
-   Apple transaction verification/restoration requires careful
    implementation.
-   Allowance policy requires operational monitoring.

## 43. Alternatives Considered

### App Store introductory free trial only

Rejected for V1 because Oreamy uses a backend-controlled 30-day product
trial beginning when the `ServiceUser` is created.

### Device-local trial

Rejected because reinstall/device replacement could reset or lose trial
state.

### No free AI after trial

Rejected because it creates a hard dead-end and weakens
retention/reactivation.

### Lock all history after expiration

Rejected because it conflicts with trust, retention, and private-data
principles.

### Unlimited AI with no server guard

Rejected because recurring provider costs and abuse must be controlled.

### Third-party subscription SDK

Not selected for V1. StoreKit 2 plus Oreamy backend is sufficient.

## 44. Implementation Guidance

Implement in small independently testable steps:

1.  Backend trial/service-access domain.
2.  Backend configurable plan-aware AI allowance.
3.  StoreKit 2 product and entitlement layer on iOS.
4.  Step 8C-1: `appAccountToken` purchase ownership, backend entitlement
    model, authenticated synchronization boundary, Apple-signed JWS
    verification foundation, and idempotency/security tests.
5.  Step 8C-2: App Store Server API reconciliation, App Store Server
    Notifications V2, production credentials/configuration, and
    lifecycle reconciliation.
6.  Paywall and subscription-management UI.
7.  Restore purchase.
8.  Trial/free/premium UX.
9.  StoreKit/App Store sandbox end-to-end verification.

Do not implement the entire subscription system in one large step.
If an Apple credential is required before a slice can be implemented
correctly, stop rather than inventing credentials or weakening
verification.

## 45. Decision Status

**Accepted**

The accepted V1 policy is:

-   Monthly/annual paid products remain in one StoreKit subscription
    group.
-   FREE allowance is 3 AI extractions per UTC calendar month.
-   Premium Trial and verified paid Premium allowance is 300 AI
    extractions per UTC calendar month.
-   `ServiceUser` creation is the exact trial activation boundary.
-   StoreKit verified entitlement and renewal state drive local paid
    presentation.
-   Apple-signed StoreKit transaction JWS, verified by the backend and
    bound to the authenticated `ServiceUser` through `appAccountToken`,
    is the V1 paid-entitlement evidence.
-   App Store Server API reconciliation and App Store Server
    Notifications V2 maintain authoritative paid-entitlement lifecycle
    state.
