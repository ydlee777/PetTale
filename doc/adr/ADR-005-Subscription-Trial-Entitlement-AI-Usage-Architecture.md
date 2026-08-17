# ADR-005 --- Subscription, Trial, Entitlement and AI Usage Architecture

**Status:** Accepted\
**Date:** 2026-08-17\
**Decision Owners:** Pettale\
**Scope:** iOS V1 subscription, Premium trial, free/archive access,
entitlement synchronization, and AI usage authorization

## 1. Context

Pettale is a commercial consumer application whose core paid value is
the ability to quickly create structured pet-life records using:

**Voice → on-device Speech-to-Text → Pettale AI extraction → Diary +
structured events → long-term pet history**

Private pet data remains in the Apple-side persistence architecture (Pet
profiles, PetRecord, original transcript, diary text, PetEvent,
weight/health history, Diary/Timeline, and derived local statistics).

Pettale backend stores service-management data only: service identity,
authentication, AI usage, entitlement information, and
subscription/trial state.

Pet history must not be moved to the Pettale backend merely to support
subscriptions.

## 2. Decision

Pettale will use a three-layer authority model:

**Apple StoreKit 2 → Pettale Backend → Pettale iOS App**

-   **Apple** is authoritative for App Store subscription entitlement.
-   **Pettale Backend** is authoritative for service access, trial
    state, AI allowance, and authorization of server-side AI operations.
-   **iOS App** presents products/prices, initiates purchases, restores
    purchases, observes StoreKit entitlement, synchronizes entitlement
    with the backend, and preserves local access to existing pet
    history.

The iOS client is not the final authority for paid AI access.

## 3. V1 Commercial Plans

Three service states:

-   `PREMIUM_TRIAL`
-   `PREMIUM`
-   `FREE`

`FREE` also represents post-trial/post-subscription archive mode.

## 4. Premium Trial

Pettale provides **30 days of Premium access**.

The V1 Premium Trial is a **Pettale service trial**, not an App Store
introductory subscription trial. Apple introductory offers may be
evaluated later.

## 5. Trial Start

The trial does not begin on install, launch, Pet creation, Sign in with
Apple, or browsing.

It begins on the **first successful AI-powered diary/event extraction**
accepted as a successful Pettale AI operation.

Failed AI requests do not start the trial.

## 6. Trial Authority

Trial state is authoritative in the Pettale backend. It should persist
sufficient information such as `trial_started_at` and
`trial_expires_at`, or an equivalent entitlement model.

Trial state must not rely solely on UserDefaults, Keychain, installation
date, or device-local state.

## 7. Trial Eligibility

One Pettale Premium Trial per `ServiceUser`.

Reinstalling Pettale or changing iPhones must not create a new trial for
the same service identity.

## 8. Trial Access

During an active trial, the user receives Premium functionality subject
to server-side AI fair-use controls.

Existing private pet history remains Apple-side.

## 9. Premium Subscription Products

Initial target pricing:

-   Monthly: **US\$4.99/month**
-   Annual: **approximately US\$47.99/year**

Final storefront prices are configured in App Store Connect. Pettale
must display StoreKit-provided localized pricing rather than hard-coded
USD prices.

## 10. StoreKit

Pettale V1 uses **StoreKit 2** and native Apple frameworks.

StoreKit handles product loading, purchase flow, on-device transaction
verification, entitlement observation, restoration, and
subscription-status presentation.

No third-party subscription SDK is introduced for V1.

## 11. Subscription Product Structure

Monthly and annual Premium products belong to one subscription group:

-   Pettale Premium Monthly
-   Pettale Premium Annual

Both grant the same Premium entitlement.

## 12. Premium Entitlement

An active verified Premium subscription grants `PREMIUM` service access.

Product identifiers remain configuration constants, not user-facing
text.

## 13. Server-Side Subscription Verification

The backend must never trust client assertions such as
`{ "premium": true }`.

Premium authority must be based on verified Apple subscription evidence
and/or supported App Store server-side transaction mechanisms.

The client may forward entitlement evidence but cannot self-assert
Premium status.

## 14. AI Authorization

Every server-side paid AI operation is authorized by the Pettale
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
-   existing Diary and diary text
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

`PETTALE_AI_FREE_MONTHLY_REQUEST_LIMIT=3`

The value is product policy, not an architectural constant.

## 18. Premium AI Allowance

Initial V1 fair-use guard:

**100 AI extraction operations per UTC calendar month**

Configurable, e.g.:

`PETTALE_AI_PREMIUM_MONTHLY_REQUEST_LIMIT=100`

This is a cost/abuse guard rather than a product promise that Premium is
limited to exactly 100 records forever.

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

-   `PETTALE_AI_FREE_MONTHLY_REQUEST_LIMIT=1000`
-   `PETTALE_AI_PREMIUM_MONTHLY_REQUEST_LIMIT=1000`

Do not delete usage rows, bypass authentication, or disable quota
enforcement in code.

## 22. Subscription Expiration

`PREMIUM → FREE`

Existing local data remains untouched and requires no data migration.

## 23. Subscription Cancellation

Cancellation of auto-renewal does not immediately remove Premium. Access
remains until Apple's verified entitlement expiration.

## 24. Billing Problems

Grace period and billing retry behavior follow verified Apple
subscription status. Pettale does not invent separate billing-state
semantics.

## 25. Restore Purchases

Pettale provides a standard **Restore Purchases** action.

Restoration refreshes verified entitlement and synchronizes service
access with the backend.

## 26. Device Replacement

Recovery paths remain separate:

-   Pet history → SwiftData/private CloudKit
-   Service identity → Sign in with Apple
-   Premium entitlement → Apple subscription entitlement/restore
-   Trial state → Pettale backend

## 27. Authentication and Subscription

Local private history can be browsed without a functioning backend
session.

Server-side AI and subscription synchronization require authenticated
Pettale service identity.

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

Communicate that Pettale history remains available and Premium provides
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
entitlement operation, potentially including:

-   ServiceUser association
-   trial start/expiration
-   subscription product
-   entitlement state
-   verified expiration
-   last synchronization timestamp
-   Apple transaction/original transaction identifiers where
    operationally required

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

  Verified Premium entitlement        Apple evidence verified for Pettale
                                      service

  Pettale trial                       Pettale backend

  AI usage count                      Pettale backend `ai_usage`

  AI operation authorization          Pettale backend

  Local history browsing              iOS local/private Apple data

  Localized subscription price        StoreKit

  OpenAI credentials                  Pettale backend
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

  AI voice diary      Premium allowance  Premium allowance     Free allowance

  Initial monthly AI                100                100                  3
  allowance

  Purchase/upgrade                  Yes             Manage                Yes

  Restore purchase                  Yes                Yes                Yes
  ---------------------------------------------------------------------------

Allowance values are configurable V1 policy, not architectural
constants.

## 40. Why Not Lock Historical Records?

Pettale's long-term value comes from years of personal pet history.

Locking existing records after subscription expiration would reduce
trust, discourage retention, and conflict with the private/local
architecture.

Subscriptions monetize ongoing AI-assisted recording and future Premium
services, not access to the user's own existing history.

## 41. Why Provide Free AI Usage?

A small FREE allowance supports continued engagement, reminds users of
Pettale's value, creates a path back to Premium, and reduces post-trial
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
-   Free users retain a reason to keep Pettale installed.
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

Rejected for V1 because Pettale wants the 30-day product trial to begin
on first successful AI use.

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

Not selected for V1. StoreKit 2 plus Pettale backend is sufficient.

## 44. Implementation Guidance

Implement in small independently testable steps:

1.  Backend trial/service-access domain.
2.  Backend configurable plan-aware AI allowance.
3.  StoreKit 2 product and entitlement layer on iOS.
4.  Server-side Apple entitlement verification/synchronization.
5.  Paywall and subscription-management UI.
6.  Restore purchase.
7.  Trial/free/premium UX.
8.  StoreKit/App Store sandbox end-to-end verification.

Do not implement the entire subscription system in one large step.

## 45. Decision Status

**Proposed**

Move to **Accepted** before implementation after confirming:

-   Monthly/annual product identifiers
-   Final initial FREE allowance
-   Final initial Premium fair-use limit
-   First successful AI extraction as the exact trial activation
    boundary
-   Apple entitlement verification implementation approach
