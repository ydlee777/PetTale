package com.oreamy.backend.usage;

public enum AiFailureCategory {
    PROVIDER_ERROR,
    TIMEOUT,
    RATE_LIMIT,
    REFUSAL,
    INCOMPLETE,
    MISSING_OUTPUT,
    INVALID_STRUCTURED_OUTPUT,
    INVALID_RESPONSE,
    STALE_RESERVATION
}
