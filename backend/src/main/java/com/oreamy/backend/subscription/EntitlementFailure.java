package com.oreamy.backend.subscription;

public final class EntitlementFailure extends RuntimeException {
    private final String code;

    public EntitlementFailure(String code) {
        super(code);
        this.code = code;
    }

    public String code() { return code; }
}
