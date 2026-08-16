package com.pettale.backend.usage;

public record AiProviderMetadata(
        String provider,
        String model,
        Long inputTokens,
        Long outputTokens,
        String providerRequestId) {
    void validate() {
        if (inputTokens != null && inputTokens < 0) throw new IllegalArgumentException("inputTokens must be nonnegative");
        if (outputTokens != null && outputTokens < 0) throw new IllegalArgumentException("outputTokens must be nonnegative");
    }
}
