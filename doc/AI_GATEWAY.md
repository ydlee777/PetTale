# AI gateway and usage control

Pettale's backend owns the AI provider boundary. The iOS app must authenticate with a Pettale bearer JWT and must never contain or call an AI provider with a private provider credential.

## Boundary and lifecycle

Step 3C introduces the internal `AiGatewayService`, the `AiProvider` port, and `AiUsageService`. It intentionally exposes no production extraction endpoint and makes no OpenAI call. Step 3D can connect the authenticated extraction controller and provider adapter without changing usage accounting.

An `EVENT_EXTRACTION` attempt is reserved before provider invocation. `RESERVED` and `SUCCEEDED` rows count toward the current allowance; `FAILED` rows remain for safe operational diagnostics but do not consume quota. A successful completion may record provider, configured model, input/output token counts, and provider request ID. Failures record only a canonical category. Transcript, prompt, response, audio, and pet history are never stored in `ai_usage`.

## Quota semantics

The temporary V1 policy allows 25 counted requests per ServiceUser and operation per UTC calendar month. `PETTALE_AI_MONTHLY_REQUEST_LIMIT` overrides this default. Month windows are half-open intervals from 00:00:00 UTC on the first day through, but excluding, the first day of the next month.

Reservation locks the caller's `service_user` row in the PostgreSQL transaction, counts current `RESERVED` and `SUCCEEDED` rows, and inserts only when below the limit. This serializes concurrent reservations for one user without Redis or distributed locking. Future subscription policy can resolve a different allowance before reservation without changing `ai_usage`.

## Configuration and privacy

- `PETTALE_AI_MONTHLY_REQUEST_LIMIT`: temporary monthly allowance; default `25`.
- `PETTALE_EXTRACTION_MODEL`: prepared server-side model selection; default `gpt-5-mini`. It is not invoked in Step 3C.
- `PETTALE_SESSION_LIFETIME`: Pettale JWT duration; V1 default `P30D`.

No OpenAI key is configured in Step 3C. Provider credentials belong only in server-side secret management when the provider adapter is implemented.
