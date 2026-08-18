package com.oreamy.backend.ai;

import java.time.Instant;

public record ExtractedEventDraft(
        EventCategory category,
        String eventType,
        Instant occurredAt,
        Double numericValue,
        String unit,
        Integer count,
        Integer durationMinutes,
        String description) {}
