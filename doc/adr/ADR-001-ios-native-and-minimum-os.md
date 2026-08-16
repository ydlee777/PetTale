# ADR-001: iOS Native V1 and Minimum OS Policy

- **Status:** Accepted
- **Date:** 2026-08-16
- **Decision Owners:** Pettale
- **Applies To:** Pettale V1

## Context

Pettale V1 is an iPhone application whose core workflow is:

**Speak → Speech-to-text → AI extraction → Structured pet events → Diary/history**

The product should be fast, simple, privacy-conscious, and economical to operate. Apple-native technologies provide the most direct implementation path for the initial iPhone-only release.

Speech-to-text is a core dependency. Pettale intends to use Apple's modern Speech framework and a `SpeechAnalyzer`-based implementation rather than maintaining multiple speech stacks merely to support older iOS versions.

Android may be developed later, but hypothetical Android requirements must not complicate the iOS V1.

## Decision

Pettale V1 will be implemented as a **native iPhone application** using:

- Swift
- SwiftUI
- Xcode
- Swift Concurrency
- Apple-native frameworks whenever practical

The minimum deployment target will be the **minimum iOS version that supports the selected production `SpeechAnalyzer` implementation**.

Before the Xcode project deployment target is finalized, the implementation team must verify the exact required iOS version against the current Xcode SDK and Apple documentation.

Pettale V1 will not implement a second legacy speech-to-text architecture solely to support older iOS versions.

Android is explicitly outside V1 scope.

If Android is added later, the preferred direction is a separate native Android application, potentially using Kotlin and Jetpack Compose.

## Rationale

This decision:

- Keeps V1 implementation simple.
- Allows Pettale to use modern Apple speech APIs.
- Reduces compatibility code and testing.
- Maximizes integration with iOS.
- Supports rapid development with Swift/SwiftUI.
- Avoids adopting a cross-platform framework for a platform that is not yet required.

Future Android compatibility will be achieved through platform-independent service APIs, schemas, canonical event codes, and business rules rather than shared UI code.

## Consequences

### Positive

- Smaller V1 implementation surface.
- Modern Apple APIs can be used directly.
- Less legacy compatibility code.
- Easier Xcode and device testing.
- Better access to Apple-native privacy, speech, subscription, and cloud capabilities.

### Negative / Trade-offs

- Users on unsupported older iOS versions cannot install Pettale.
- A future Android application will require separate client implementation.
- Exact minimum iOS version becomes dependent on the selected Speech framework APIs.

## Implementation Rules

1. Verify and record the exact minimum iOS deployment target before feature implementation.
2. Use SwiftUI for new V1 UI.
3. Prefer Apple-native frameworks over third-party dependencies.
4. Do not add legacy STT support solely to lower the deployment target.
5. Test SpeechAnalyzer with both English and Korean on real supported iPhones.
6. Do not introduce Flutter, React Native, or another cross-platform UI framework without a new architectural decision.

## Revisit When

Revisit this ADR if:

- Apple changes SpeechAnalyzer availability materially.
- Supported-device coverage creates a demonstrated commercial problem.
- Android becomes an approved product initiative.
- A critical iOS requirement cannot reasonably be met with the selected native architecture.
