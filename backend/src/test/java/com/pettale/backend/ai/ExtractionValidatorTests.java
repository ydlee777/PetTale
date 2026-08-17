package com.pettale.backend.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;

class ExtractionValidatorTests {
    private static final Instant RECORDED_AT = Instant.parse("2026-08-16T12:00:00Z");
    private final ExtractionValidator validator = new ExtractionValidator();

    @Test void acceptsCanonicalBodyWeightEvent() {
        var event = weight("BODY_WEIGHT");

        assertThat(validator.validate("2", "오늘 오레오의 체중은 6.2kg이에요.", List.of(event)).events()).containsExactly(event);
    }

    @Test void rejectsCategoryNameAsWeightEventType() {
        assertRejected(weight("WEIGHT"));
    }

    @Test void rejectsArbitraryWeightEventType() {
        assertRejected(weight("PET_MASS"));
    }

    @Test void acceptsCanonicalVomitingEvent() {
        var event = health("VOMITING");

        assertThat(validator.validate("2", "오늘 오레오가 한 번 토했어요.", List.of(event)).events()).containsExactly(event);
    }

    @Test void rejectsPastTenseVomitedAlias() {
        assertRejected(health("VOMITED"));
    }

    @Test void rejectsVomitAlias() {
        assertRejected(health("VOMIT"));
    }

    private void assertRejected(ExtractedEventDraft event) {
        assertThatThrownBy(() -> validator.validate("2", "Valid diary", List.of(event)))
                .isInstanceOf(ProviderFailure.class)
                .satisfies(error -> assertThat(((ProviderFailure) error).kind())
                        .isEqualTo(ProviderFailure.Kind.INVALID_STRUCTURED_OUTPUT));
    }

    @Test void acceptsKoreanAndEnglishDiaryText() {
        assertThat(validator.validate("2", "오늘 오레오의 체중은 6.2kg이에요.", List.of(weight("BODY_WEIGHT"))).diaryText())
                .contains("오레오");
        assertThat(validator.validate("2", "Oreo weighs 6.2 kg today.", List.of(weight("BODY_WEIGHT"))).diaryText())
                .isEqualTo("Oreo weighs 6.2 kg today.");
    }

    @Test void rejectsBlankAndOversizedDiaryText() {
        assertThatThrownBy(() -> validator.validate("2", "  ", List.of(weight("BODY_WEIGHT"))))
                .isInstanceOf(ProviderFailure.class);
        assertThatThrownBy(() -> validator.validate("2", "a".repeat(ExtractionValidator.MAX_DIARY_TEXT + 1),
                List.of(weight("BODY_WEIGHT")))).isInstanceOf(ProviderFailure.class);
    }

    private ExtractedEventDraft weight(String eventType) {
        return new ExtractedEventDraft(
                EventCategory.WEIGHT, eventType, RECORDED_AT, 6.2, "KG", null, null, null);
    }

    private ExtractedEventDraft health(String eventType) {
        return new ExtractedEventDraft(
                EventCategory.HEALTH, eventType, RECORDED_AT, null, null, 1, null, null);
    }
}
