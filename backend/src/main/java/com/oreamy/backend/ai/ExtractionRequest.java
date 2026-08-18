package com.oreamy.backend.ai;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.AssertTrue;
import jakarta.validation.constraints.Size;
import java.time.DateTimeException;
import java.time.Instant;
import java.time.ZoneId;
import java.util.List;
import java.util.UUID;

public record ExtractionRequest(
        @NotBlank @Size(max = 10_000) String transcript,
        @NotNull Instant recordedAt,
        @NotNull @Valid SelectedPet selectedPet,
        @NotNull @Size(max = 20) List<@NotBlank @Size(max = 100) String> knownPetNames,
        @Pattern(regexp = "^[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$") String spokenLanguage,
        @NotBlank @Size(max = 100) String timeZone) {

    public record SelectedPet(@NotNull UUID clientPetId, @NotBlank @Size(max = 100) String name) {}

    AiProvider.ExtractionInput toProviderInput() {
        return new AiProvider.ExtractionInput(
                transcript.trim(), recordedAt, selectedPet.name().trim(),
                knownPetNames.stream().map(String::trim).distinct().toList(), spokenLanguage,
                ZoneId.of(timeZone).getId());
    }

    @AssertTrue(message = "timeZone must be a supported time-zone identifier")
    public boolean isTimeZoneSupported() {
        if (timeZone == null || timeZone.isBlank()) return true;
        try {
            ZoneId.of(timeZone);
            return true;
        } catch (DateTimeException error) {
            return false;
        }
    }
}
