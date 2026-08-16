package com.pettale.backend.ai;

/** Server-side port for the structured event extraction adapter implemented in Step 3D. */
public interface AiProvider {
    ExtractionResult extractEvents(ExtractionInput input);

    record ExtractionInput(String transcript) {}
    record ExtractionResult(
            String provider,
            String model,
            long inputTokens,
            long outputTokens,
            String providerRequestId,
            String structuredResult) {}
}
