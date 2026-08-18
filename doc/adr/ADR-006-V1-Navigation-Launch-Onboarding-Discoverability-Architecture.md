# ADR-006 --- V1 Navigation, Launch, Onboarding and Discoverability Architecture

> **Product rename note (2026-08-18):** Pettale was renamed to Oreamy
> before release. The decision itself is unchanged; current product
> references use Oreamy.

**Status:** Accepted\
**Date:** 2026-08-17\
**Decision Owners:** Oreamy\
**Scope:** iPhone V1 launch experience, first-run onboarding, root
navigation, pet switching, global menu, secondary-screen navigation,
feature discoverability, and sheet usage.

## 1. Context

Oreamy V1 now includes Pet profiles, voice recording, on-device STT, AI
diary/event extraction, Diary, Weight Trend, Health History, Record
Summary, authentication, Premium Trial/service-access foundation, and
StoreKit 2.

Physical-device QA showed that individual screens work, but the overall
application is difficult to navigate. Important problems include
ambiguous top-level actions, subscription discoverability, Premium
presented as a swipe-dismiss sheet, statistics counts that cannot be
inspected, and the unclear Diary tab label `Open / 열기`.

Oreamy is a consumer pet-life diary. Users should not need to learn the
application hierarchy before recording or reviewing their pet's story.

## 2. Decision

Oreamy V1 uses three navigation layers:

1.  **Root bottom navigation** for `Today / 오늘` and `Diary / 일기`.
2.  **NavigationStack push navigation** for features and detail screens.
3.  **A global menu** as the complete discovery/settings entry point.

Pet switching is a global context selector rather than a generic add
action.

``` text
Oreamy
├── Today
│   ├── Record
│   ├── Recent Record → Record Detail
│   ├── Weight
│   ├── Health History
│   └── Record Summary
├── Diary
│   └── Record Detail
├── Pet Selector
│   ├── Switch Pet
│   ├── Add Pet
│   └── Manage Pets
└── Menu
    ├── Manage Pets
    ├── Diary
    ├── Weight
    ├── Health History
    ├── Record Summary
    ├── Oreamy Premium
    ├── Account
    ├── Settings
    └── Information
```

## 3. Root Navigation

The bottom navigation contains exactly two primary destinations:

-   `Today / 오늘`
-   `Diary / 일기`

`Open / 열기` must not be used for Diary. Bottom navigation represents
destinations, not actions.

V1 does not add root tabs for Weight, Health, Statistics, Premium, or
Settings.

## 4. Today as Home

Today is Oreamy's primary home screen.

It must make the following obvious:

-   selected pet;
-   primary Record action;
-   recent story/record;
-   Weight;
-   Health History;
-   Record Summary.

Today remains warm and pet-centered rather than becoming a dense
dashboard.

## 5. Diary

Diary is the chronological pet-life history and remains directly
accessible from the bottom navigation.

Diary cards navigate to Record Detail through normal push navigation.

## 6. Secondary Screens and Back Navigation

Feature/detail screens use NavigationStack push navigation, including:

-   Weight
-   Health History
-   Record Summary
-   Record Detail
-   Filtered Event Records
-   Pet Management
-   Account
-   Oreamy Premium
-   Settings
-   Information

Every pushed secondary screen must provide a clear standard upper-left
Back path.

Native swipe-back gestures may remain, but they are supplementary rather
than the only return mechanism.

## 7. Push vs Sheet

**Information destinations use push navigation. Temporary tasks use
sheets.**

Push examples:

-   Weight
-   Health History
-   Record Summary
-   Record Detail
-   Account
-   Premium
-   Settings
-   Pet Management

Sheet examples:

-   photo selection;
-   event editing;
-   date selection;
-   temporary pet selection;
-   confirmation.

Important destinations must not depend on swipe-down dismissal.

## 8. Premium Navigation

Premium changes from a sheet-style destination to normal push
navigation.

Typical routes:

``` text
Menu → Oreamy Premium → < Menu
Account → Oreamy Premium → < Account
```

This does not change StoreKit entitlement or backend subscription
authority.

## 9. Global Menu

Oreamy provides a global menu so a user who does not know where a
feature lives can reliably find it.

Recommended structure:

``` text
Menu

Pets
  Manage Pets

Records
  Diary
  Weight
  Health History
  Record Summary

Oreamy
  Oreamy Premium
  Account
  Settings

Information
  Privacy
  Terms
  About Oreamy
```

The global menu is not a third bottom tab.

## 10. Global Menu Entry Point

The top-right main-screen area provides a recognizable menu entry point.
A conventional menu symbol such as `☰` is preferred when it improves
discoverability.

The Account remains a destination inside the menu rather than
simultaneously serving as Account, Settings, Subscription, and global
navigation.

## 11. Pet Selector

The selected pet is global context.

The top-left pet control should communicate that it is selectable, for
example:

``` text
Oreo ▾
```

Selecting it provides:

-   current pet indication;
-   other pets;
-   Add Pet;
-   Manage Pets.

The ambiguous global `+` control is not required for pet creation.

## 12. Pet Context Preservation

Navigation preserves the selected pet unless the user explicitly changes
it.

Weight, Health History, Record Summary, Diary, and recording flows
continue to use their existing ownership/isolation rules.

## 13. Launch Experience

Oreamy provides a short branded launch experience:

``` text
App Launch
→ Apple Launch Screen
→ Oreamy Intro
  "Every pet has a tale."
→ Today or First-Run Welcome
```

Target:

-   approximately 1--1.5 seconds;
-   native SwiftUI animation;
-   calm and warm;
-   no network/backend dependency;
-   no CloudKit synchronization wait;
-   no artificial multi-second delay.

The intro is product identity, not a loading screen.

## 14. Launch Screen vs Animated Intro

The static Apple Launch Screen follows Apple's launch-screen
constraints.

The animated Oreamy intro runs afterward as normal application UI and
may animate Oreamy branding, a subtle pet-related mark, and:

> Every pet has a tale.

No external animation framework is required.

## 15. Returning Users

Returning users should reach Today quickly:

``` text
Launch → brief Oreamy intro → Today
```

The intro must not become a barrier to Oreamy's under-10-second daily
recording goal.

## 16. First-Run Onboarding

Splash/intro and onboarding are separate.

A first-time user without a pet follows:

``` text
Launch → Oreamy Intro → Welcome → Create First Pet → Today
```

Onboarding explains Oreamy simply:

> Oreamy\
> Every pet has a tale.\
> Tell Oreamy about your pet's day. We'll help turn it into a story and
> organized records.

Exact copy may be refined during implementation.

## 17. Authentication on First Run

Sign in with Apple is not required merely to reach the first local pet
experience unless a concrete online service operation requires
authentication.

Existing local/private-history principles remain.

## 18. Subscription on First Run

Do not show a mandatory subscription paywall during first
launch/onboarding.

ADR-005 remains authoritative:

-   30-day Oreamy Trial begins when the backend creates a new
    `ServiceUser`;
-   trial is backend-managed;
-   existing history remains accessible without Premium.

## 19. Record Discoverability

Recording is Oreamy's primary action and must be visually obvious on
Today.

Preferred hierarchy:

``` text
Selected Pet
→ Record today's story
→ Recent story/history shortcuts
```

The user should not need the global menu to start a recording.

## 20. Record Summary Drill-Down

Record Summary must not show counts that cannot be inspected.

Supported rows should be navigable:

``` text
Food Records       2  >
Activity Records   1  >
Health Records     1  >
Vet Records        1  >
```

The user must be able to inspect the records contributing to each
displayed count.

## 21. Filtered Event Records

Do not create separate large Food History and Activity History modules
merely for drill-down.

Prefer a reusable filtered-event presentation when existing views cannot
be reused.

The filtered list preserves:

-   selected pet;
-   selected summary period;
-   existing event semantics.

## 22. Existing Feature Reuse

Where an existing feature already provides correct detail semantics,
reuse it rather than creating duplicate implementations.

Inspect existing screens before implementing new history/detail paths.

## 23. Navigation Labels

Preferred destination labels:

-   Today / 오늘
-   Diary / 일기
-   Weight / 체중
-   Health History / 건강 기록
-   Record Summary / 기록 요약
-   Oreamy Premium
-   Account / 계정
-   Settings / 설정

Avoid ambiguous labels such as `Open / 열기` or generic unlabeled add
actions.

## 24. Discoverability

Important features may have more than one route:

``` text
Today → Weight
Menu → Weight
```

This is intentional navigation redundancy, not duplicate functionality.
Both routes resolve to the same implementation.

## 25. Back Navigation Principle

If a user enters a pushed screen, the upper-left Back control returns to
the screen they came from.

Do not unexpectedly return to Home when normal stack behavior should
return to the previous screen.

## 26. Navigation Depth

V1 avoids unnecessarily deep hierarchies.

Typical depth:

``` text
Root → Feature → Detail
Menu → Feature → Detail
```

Do not introduce nested navigation stacks without concrete need.

## 27. Visual Principles

Navigation cleanup preserves Oreamy's visual principles:

-   simple;
-   warm;
-   personal;
-   calm;
-   pet-centered;
-   native iOS behavior.

Do not turn Today or Menu into an enterprise dashboard.

## 28. Localization

All navigation destinations, onboarding copy, menu labels, and empty
states support English and Korean.

User-generated content is not translated merely because the application
UI language changes.

## 29. Accessibility

Provide meaningful accessibility labels for:

-   selected pet;
-   pet selector;
-   menu;
-   Today tab;
-   Diary tab;
-   Back;
-   Record;
-   feature shortcuts;
-   summary drill-down rows.

Meaning must not depend solely on icons.

## 30. Dynamic Type

Navigation labels and primary actions remain usable with Dynamic Type.

Avoid fixed widths that truncate critical destination names in Korean or
English.

## 31. State Restoration

V1 does not require restoration of an arbitrary deep navigation stack
after app termination.

Do not add speculative navigation-persistence infrastructure.

## 32. Offline Behavior

Existing local/private history navigation works without the Oreamy
backend, including:

-   Diary
-   Weight
-   Health History
-   Record Summary
-   local record details.

## 33. StoreKit Boundary

This ADR changes Premium presentation/navigation only.

Step 8B StoreKit architecture remains:

``` text
SwiftUI
→ SubscriptionController
→ StoreKitService
→ AppleStoreKitService
→ StoreKit 2
```

Local StoreKit entitlement remains separate from Oreamy backend service
authorization until the approved server synchronization step.

## 34. Backend Boundary

No navigation decision moves pet history to the backend.

This ADR does not change:

-   ServiceUser trial semantics;
-   AI usage accounting;
-   AI quotas;
-   authentication authority;
-   subscription entitlement authority.

No PostgreSQL schema change is required by this ADR.

## 35. SwiftData / CloudKit Boundary

Navigation/onboarding should not require a SwiftData schema change
unless implementation discovers a concrete requirement that cannot
otherwise be satisfied.

Pet history remains SwiftData/private CloudKit.

A lightweight first-run presentation flag may use appropriate local
application preferences if required.

## 36. Implementation Sequence

Implement in small slices.

### Step 8B-QA1 --- Navigation Foundation

-   root navigation cleanup;
-   Today / Diary naming;
-   global menu;
-   pet selector;
-   push navigation consistency;
-   visible Back controls;
-   Premium sheet → push.

### Step 8B-QA2 --- Launch & First-Run

-   Apple Launch Screen review;
-   short Oreamy animated intro;
-   Welcome;
-   first Pet creation path;
-   returning-user fast path.

### Step 8B-QA3 --- Today Discoverability

-   Today information hierarchy;
-   prominent Record CTA;
-   recent record;
-   Weight / Health / Summary shortcuts;
-   remove ambiguous global `+`.

### Step 8B-QA4 --- Summary Drill-Down

-   tappable supported count rows;
-   filtered event list/reuse;
-   selected period preservation;
-   selected pet preservation.

### Step 8B-QA5 --- Full V1 UX QA

-   English/Korean;
-   Light/Dark;
-   Dynamic Type;
-   VoiceOver;
-   Back behavior;
-   Pet switching;
-   empty states;
-   StoreKit screens;
-   physical iPhone walkthrough;
-   full regression.

Do not implement all slices in one large change.

## 37. Explicitly Out of Scope

This ADR does not approve:

-   Step 8C backend StoreKit entitlement synchronization;
-   App Store Server API;
-   App Store Server Notifications;
-   new subscription products;
-   Apple introductory trial;
-   Weekly Summary;
-   Monthly Summary;
-   Ask Oreamy;
-   analytics upload;
-   backend pet-history storage;
-   AI extraction redesign;
-   persistence redesign.

## 38. Consequences

### Positive

-   Predictable visible Back navigation.
-   Clear root destinations.
-   Explicit Diary naming.
-   Discoverable pet switching/creation.
-   A reliable global feature menu.
-   Premium becomes a normal navigable destination.
-   Summary metrics lead to underlying records.
-   First launch communicates Oreamy's brand and purpose.
-   Existing features become easier to discover without adding root
    tabs.

### Negative / Trade-offs

-   Navigation cleanup touches multiple existing screens.
-   Some routes intentionally appear both on Today and in Menu.
-   Animated intro adds a small startup delay.
-   First-run onboarding adds UI state to test.
-   Existing sheet-based navigation requires refactoring.
-   Physical-device QA remains important.

## 39. Alternatives Considered

### Keep the current incremental navigation

Rejected because physical-device QA showed that feature discovery and
return navigation are unclear.

### Add more bottom tabs

Rejected because Weight, Health, Summary, Premium, and Settings are
secondary destinations and additional tabs would make the app feel like
a dashboard.

### Use Account as the global menu

Rejected because Account, subscription, settings, pet management, and
feature navigation are different concepts. Overloading Account reduces
discoverability.

### Use sheets for most secondary screens

Rejected because important destinations become gesture-dependent and the
return path is unclear.

### Use only Today shortcuts without a global menu

Rejected because users still need a reliable fallback when they do not
know where a feature is located.

### Show a mandatory paywall during onboarding

Rejected because Oreamy should demonstrate value before requiring a
purchase and ADR-005 keeps existing history accessible without Premium.

## 40. Decision Status

**Accepted**

This ADR becomes the navigation and first-run baseline for the remaining
Oreamy V1 work.

Any future change that materially alters the root navigation model,
trial/paywall placement, or pet-context model should update or supersede
this ADR.
