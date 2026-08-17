# AI gateway and usage control

Pettale's backend owns the AI provider boundary. The iOS app must authenticate with a Pettale bearer JWT and must never contain or call an AI provider with a private provider credential.

## Boundary and lifecycle

`POST /api/v1/ai/extractions` is the authenticated product boundary. It reserves usage, invokes the server-only OpenAI adapter exactly once, validates the strict structured result, records safe provider metadata, and returns transient diary text plus event drafts. The endpoint never persists a transcript, diary text, pet context, or extracted event.

The transient request requires the recording session's IANA `timeZone`. The backend validates it with Java `ZoneId` before usage reservation or provider invocation. OpenAI receives both the absolute `recordedAt` instant and validated zone, interprets local expressions only in that zone, and returns absolute UTC `occurredAt` values. Language is never used to infer time zone, and the zone is not persisted.

An `EVENT_EXTRACTION` attempt is reserved before provider invocation. `RESERVED` and `SUCCEEDED` rows count toward the current allowance; `FAILED` rows remain for safe operational diagnostics but do not consume quota. A successful completion may record provider, configured model, input/output token counts, and provider request ID. Failures record only a canonical category. Transcript, prompt, response, audio, and pet history are never stored in `ai_usage`.

## Quota semantics

The V1 policy allows 3 FREE requests and 100 PREMIUM_TRIAL/PREMIUM requests per ServiceUser and operation per UTC calendar month. `PETTALE_AI_FREE_MONTHLY_REQUEST_LIMIT` and `PETTALE_AI_PREMIUM_MONTHLY_REQUEST_LIMIT` override these defaults. A never-started, trial-eligible user receives the Premium allowance so the first successful extraction can activate the trial. Month windows are half-open intervals from 00:00:00 UTC on the first day through, but excluding, the first day of the next month.

Reservation locks the caller's `service_user` row in the PostgreSQL transaction, resolves service access, counts current `RESERVED` and `SUCCEEDED` rows, and inserts only when below that plan's limit. This serializes concurrent reservations for one user without Redis or distributed locking.

After provider output passes Pettale validation, the `SUCCEEDED` transition and first trial activation occur in one transaction under the same user-row lock. Failure paths leave trial dates null. Later successes cannot reset or extend an existing trial. Trial state is derived with the backend `Clock`; the exact expiration instant resolves to FREE without a scheduled mutation.

Before counting, reservations older than `PETTALE_AI_RESERVATION_TIMEOUT` (default two minutes) are deterministically finalized as `FAILED / STALE_RESERVATION` under the same user lock. This recovers process interruption without allowing immediate abandoned-request retries. Provider HTTP work is bounded by `PETTALE_OPENAI_TIMEOUT` (default 30 seconds).

## Configuration and privacy

- `PETTALE_AI_FREE_MONTHLY_REQUEST_LIMIT`: FREE monthly allowance; default `3`.
- `PETTALE_AI_PREMIUM_MONTHLY_REQUEST_LIMIT`: PREMIUM_TRIAL/PREMIUM allowance; default `100`.
- `PETTALE_TRIAL_DURATION`: service trial duration; default `P30D`.
- `PETTALE_EXTRACTION_MODEL`: server-side model selection; default `gpt-5-mini`.
- `PETTALE_EXTRACTION_REASONING_EFFORT`: Responses API reasoning effort; default `low`.
- `PETTALE_EXTRACTION_TEXT_VERBOSITY`: Responses API text verbosity; default `low`.
- `PETTALE_OPENAI_API_KEY`: required at runtime for extraction; secret and server-only.
- `PETTALE_OPENAI_BASE_URL`: official API base by default; override only for controlled testing.
- `PETTALE_OPENAI_TIMEOUT`: bounded provider request/connect timeout; default `PT30S`.
- `PETTALE_AI_RESERVATION_TIMEOUT`: stale reservation threshold; default `PT2M`.
- `PETTALE_SESSION_LIFETIME`: Pettale JWT duration; V1 default `P30D`.

For local physical-device and Simulator QA, the git-ignored `.env` may set both plan limits to `1000` before starting the backend. This raises only that local process's allowance so benchmark usage does not block development. Quota enforcement and authentication remain enabled.

`GET /api/v1/service-access` uses the same service-access resolution and UTC usage count as reservation authorization. It accepts no ownership parameter; the verified Pettale JWT subject is the only identity source. A never-started user is represented as `PREMIUM_TRIAL` with null dates and `trialEligible: true`. No StoreKit entitlement is fabricated in this step, so PREMIUM remains a future verified-entitlement boundary.

The provider uses the OpenAI Responses API with `store: false` and strict JSON Schema `pettale_event_extraction_v2`. Prompt version `pettale-event-extraction-v2` returns diary text and events together, prohibits translation, diagnosis, invented facts, and material omission, supports multiple events, and uses `recordedAt` as the temporal reference. A successful response requires nonblank `diaryText` with a 4,000 UTF-16-code-unit maximum; backend validation independently enforces this. Only provider/model/token counts/provider request ID are retained. Diary text, raw provider errors, and content are neither persisted nor logged.

For the current V1 extraction contract, every `WEIGHT` category draft represents a pet body-weight observation and therefore must use canonical `eventType = BODY_WEIGHT`. The provider instruction and schema description express this semantic rule, and backend validation independently rejects `WEIGHT` drafts with any other event type. No broader event-type taxonomy is defined yet.

An explicit pet vomiting observation uses `category = HEALTH` and canonical `eventType = VOMITING`. The provider contract prohibits the observed aliases `VOMITED` and `VOMIT`, and backend validation independently rejects those aliases. This is a focused invariant rather than a general HEALTH taxonomy.

## V1 extraction optimization decision

The approved V1 defaults are the product model alias `gpt-5-mini`, reasoning effort `low`, and text verbosity `low`. The dated provider snapshot is observed metadata, not a configured model pin. The fixed eight-case regression benchmark passed 8/8 with these settings, with 3.681 seconds median latency, 3.834 seconds average latency, and an estimated average cost of approximately $0.000944 per extraction at the benchmark pricing recorded on 2026-08-17. Preserve the fixed benchmark in `doc/OPENAI_BENCHMARK.md` for future regression comparisons.
