package com.pettale.backend.ai;

public final class ExtractionFailure extends RuntimeException {
    public enum Code {
        QUOTA_EXCEEDED, PROVIDER_TIMEOUT, PROVIDER_RATE_LIMIT, PROVIDER_ERROR, INVALID_PROVIDER_RESPONSE
    }
    private final Code code;

    public ExtractionFailure(Code code) { super(code.name()); this.code = code; }
    public Code code() { return code; }
}
