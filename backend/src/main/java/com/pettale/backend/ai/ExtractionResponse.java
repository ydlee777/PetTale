package com.pettale.backend.ai;

import java.util.List;
import java.util.UUID;

public record ExtractionResponse(String schemaVersion, UUID clientPetId, List<ExtractedEventDraft> events) {}
