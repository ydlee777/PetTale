package com.pettale.backend.ai;

import java.time.Instant;
import java.util.List;

public interface AiProvider {
    ExtractionResult extractEvents(ExtractionInput input);

    record ExtractionInput(
            String transcript,
            Instant recordedAt,
            String selectedPetName,
            List<String> knownPetNames,
            String spokenLanguage,
            String timeZone) {}

    record ExtractionResult(
            String provider,
            String model,
            long inputTokens,
            long outputTokens,
            String providerRequestId,
            String schemaVersion,
            List<ExtractedEventDraft> events) {}
}
