# Pettale — Product Baseline

**Status:** V1 Baseline  
**Purpose:** Product reference for developers and Codex.

## 1. Vision
**Pettale = Pet + Tale**  
**Core message:** *Every pet has a tale.*

Pettale is an AI-powered pet life diary. The core experience is:

**Speak → AI understands → Events are organized → Diary is created → Pettale remembers**

V1 is an iPhone-only consumer app. A normal daily record should take less than 10 seconds.

## 2. Primary Workflow
1. Select/identify pet.
2. Tap Record and speak naturally.
3. Apple speech-to-text produces a transcript.
4. Pettale AI extracts and classifies one or more events.
5. User quickly reviews/corrects the result.
6. Save.
7. Diary, history, and statistics update automatically.

One recording may create multiple events while retaining the original transcript/context.

## 3. Initial Markets
- English-speaking markets
- South Korea
- V1 UI: English and Korean
- Internal event/category codes remain language-independent.

## 4. Initial Categories
- Food
- Weight
- Health
- Medication
- Activity
- Behavior
- Sleep
- Grooming
- Vet
- Event
- Other

## 5. V1 Features
- Pet profiles
- Voice recording
- Speech-to-text
- AI extraction/classification
- Manual correction before save
- Structured event history
- Diary/timeline
- Photo attachments
- Weight trends
- Health/event timeline
- Period statistics
- Weekly/monthly summaries
- Subscription/trial management
- AI usage tracking

## 6. Monetization
Initial hypothesis:
- 30-day Premium Trial
- Premium: US$4.99/month
- Annual: approximately US$47.99
- Pricing/limits may change after measuring conversion, retention, AI cost, infrastructure cost, and gross margin.

### Free / Archive Mode
- Existing records remain accessible.
- Manual records remain possible.
- A very small monthly AI allowance may be provided.
- Advertising may be enabled later.

### Premium
- No advertising.
- Larger controlled AI allowance.
- Premium summaries/features.

Do not promise technically unlimited AI usage.

## 7. Advertising Policy
Pettale must be architected so ads can later be enabled in Free Mode, but an advertising SDK/provider is **not required for initial V1**.

- Trial: no ads
- Premium: no ads
- Free Mode: ads may be activated later
- Provider selection/integration requires a separate explicit decision.

## 8. Privacy
Pet records, transcripts, photos, and diary information are private user data.

- Private pet history is not permanently stored in the Pettale service backend by default.
- Prefer SwiftData + private iCloud/CloudKit.
- Audio is temporary and should be deleted after successful transcription unless explicitly needed.
- Photos are not automatically sent to an AI model in V1.

## 9. AI Principles
Use AI for language understanding/generation:
- Event extraction
- Classification
- Diary prose
- Weekly/monthly narrative summaries

Do not use LLMs for deterministic calculations:
- Weight averages/change
- Counts
- Date filtering
- Medication counts
- Trend calculations

## 10. V1 Non-Goals
Unless explicitly approved:
- Android app
- Consumer web app
- Generic chatbot
- Ask Pettale historical Q&A
- Automatic veterinary diagnosis
- Automatic photo diagnosis
- Social network
- Family sharing
- Initial advertising SDK integration

## 11. Future Direction
Android may later use the same API contracts, schemas, canonical codes, and business rules.

Potential later feature: **Ask Pettale**, for questions based on historical pet records.

## 12. V1 Decision Rule
> **Does this help validate whether users will repeatedly use and pay for Pettale?**

If not, strongly consider postponing it.
