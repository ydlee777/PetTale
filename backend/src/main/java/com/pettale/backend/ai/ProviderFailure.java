package com.pettale.backend.ai;

public final class ProviderFailure extends RuntimeException {
    public enum Kind {
        TIMEOUT,
        RATE_LIMIT,
        ERROR,
        REFUSAL,
        INCOMPLETE,
        MISSING_OUTPUT,
        INVALID_STRUCTURED_OUTPUT,
        INVALID_RESPONSE
    }
    private final Kind kind;

    public ProviderFailure(Kind kind) { super(kind.name()); this.kind = kind; }
    public ProviderFailure(Kind kind, Throwable cause) { super(kind.name(), cause); this.kind = kind; }
    public Kind kind() { return kind; }
}
