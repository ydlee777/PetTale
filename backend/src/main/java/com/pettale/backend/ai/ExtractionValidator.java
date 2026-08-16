package com.pettale.backend.ai;

import java.util.List;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

@Component
final class ExtractionValidator {
    private static final Logger log = LoggerFactory.getLogger(ExtractionValidator.class);
    private static final Pattern CODE = Pattern.compile("[A-Z][A-Z0-9_]{0,63}");
    private static final int MAX_DESCRIPTION = 500;

    List<ExtractedEventDraft> validate(String schemaVersion, List<ExtractedEventDraft> events) {
        if (!"1".equals(schemaVersion)) invalid("schemaVersion", "UNSUPPORTED");
        if (events == null || events.isEmpty()) invalid("events", "EMPTY");
        for (var event : events) {
            if (event == null) invalid("event", "NULL");
            if (event.category() == null) invalid("category", "NULL");
            if (event.occurredAt() == null) invalid("occurredAt", "NULL");
            if (event.eventType() != null && !CODE.matcher(event.eventType()).matches()) invalid("eventType", "CODE");
            if (event.category() == EventCategory.WEIGHT && !"BODY_WEIGHT".equals(event.eventType())) {
                invalid("eventType", "WEIGHT_REQUIRES_BODY_WEIGHT");
            }
            if (event.category() == EventCategory.HEALTH
                    && ("VOMITED".equals(event.eventType()) || "VOMIT".equals(event.eventType()))) {
                invalid("eventType", "VOMITING_REQUIRES_CANONICAL_CODE");
            }
            if (event.unit() != null && !CODE.matcher(event.unit()).matches()) invalid("unit", "CODE");
            if (event.count() != null && event.count() < 0) invalid("count", "NEGATIVE");
            if (event.durationMinutes() != null && event.durationMinutes() < 0) invalid("durationMinutes", "NEGATIVE");
            if (event.numericValue() != null && !Double.isFinite(event.numericValue())) invalid("numericValue", "NON_FINITE");
            if (event.description() != null && event.description().length() > MAX_DESCRIPTION) invalid("description", "TOO_LONG");
        }
        return List.copyOf(events);
    }

    private static void invalid(String field, String rule) {
        log.warn("OpenAI structured output rejected category=BACKEND_VALIDATION field={} rule={}", field, rule);
        throw new ProviderFailure(ProviderFailure.Kind.INVALID_STRUCTURED_OUTPUT);
    }
}
