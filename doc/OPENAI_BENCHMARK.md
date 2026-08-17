# OpenAI extraction benchmark

Real provider calls are manual and never part of the standard test suite. Start the backend with a development PostgreSQL database, a Pettale signing key, `PETTALE_OPENAI_API_KEY`, and the configured `PETTALE_EXTRACTION_MODEL` (default `gpt-5-mini`). Obtain a valid Pettale bearer session through Sign in with Apple, then exercise `POST /api/v1/ai/extractions` from the iOS Transcript Review flow or an HTTPS client. Never paste keys into source files or benchmark results.

For each case record configured/actual model, returned drafts, correct and incorrect fields, approximate end-to-end provider latency, input/output tokens from the corresponding safe `ai_usage` row, provider request ID when available, usage lifecycle result, and any hallucination or omission. Do not record the transcript or provider response body in PostgreSQL or application logs.

| Case | Language/context | Expected |
|---|---|---|
| 1 | Korean: Oreo 6.2 kg | `WEIGHT / BODY_WEIGHT / 6.2 / KG` |
| 2 | Korean: Oreo and Creamy played all day | `ACTIVITY / PLAY`; no invented duration |
| 3 | Korean: vomited once near 15:00 and played 20 min | `HEALTH / VOMITING / 1` and `ACTIVITY / PLAY / 20` |
| 4 | English: Oreo weighs 6.2 kg | `WEIGHT / BODY_WEIGHT / 6.2 / KG` |
| 5 | English: Oreo and Creamy played 20 min | `ACTIVITY / PLAY / 20` |
| 6 | STT says Oil; selected Oreo, known Oreo/Creamy | Oreo-correlated weight event; transcript unchanged |
| 7 | Weight, ate well, played 20 min | Three `WEIGHT`, `FOOD`, `ACTIVITY` drafts |
| 8 | Red and watery eye | HEALTH observation; no diagnosis |

Review the transient response in the app. Step 3D deliberately leaves the final save action disabled, so no benchmark event is written to SwiftData.

Classify each case honestly:

- `PASS`: every materially important fact is correct.
- `PARTIAL`: the draft is usable but a non-critical field or description is missing or imperfect.
- `FAIL`: a material fact is wrong, invented, or omitted.

Use this development-only worksheet. Keep transcript text out of `ai_usage`; the case number is sufficient to correlate a manually observed result.

| Case | Configured / actual model | Result summary | Correct / incorrect fields | PASS / PARTIAL / FAIL | Latency | Input / output tokens | Provider request ID | Usage lifecycle | Hallucination / omission |
|---|---|---|---|---|---:|---:|---|---|---|
| 1 | Not run | Not run | Not assessed | Not run | — | — | — | — | — |
| 2 | Not run | Not run | Not assessed | Not run | — | — | — | — | — |
| 3 | Not run | Not run | Not assessed | Not run | — | — | — | — | — |
| 4 | Not run | Not run | Not assessed | Not run | — | — | — | — | — |
| 5 | Not run | Not run | Not assessed | Not run | — | — | — | — | — |
| 6 | Not run | Not run | Not assessed | Not run | — | — | — | — | — |
| 7 | Not run | Not run | Not assessed | Not run | — | — | — | — | — |
| 8 | Not run | Not run | Not assessed | Not run | — | — | — | — | — |

Summary after execution:

```text
Total: 8
PASS: not assessed
PARTIAL: not assessed
FAIL: not assessed
```

## Step 3F diary regression

Schema v2 adds required `diaryText` to the same extraction response; it does not create a second provider request. Future runs of the fixed eight cases must continue evaluating the event expectations above and additionally verify that diary text faithfully retells every material fact in the approved transcript's language without translation, diagnosis, invented values, causes, emotions, treatment, or advice. The approved model/reasoning/verbosity baseline remains `gpt-5-mini` / `low` / `low`; the original optimization measurements remain the comparison baseline.

Use actual provider usage metadata to assess quality, latency, and cost readiness. Do not ask an LLM to calculate cost and do not invent a dollar estimate. Physical-device verification must separately exercise Voice → SpeechAnalyzer → Transcript → OpenAI → Event Draft Review, including one Korean multi-event note; record it as not run unless it was performed on an actual iPhone.
