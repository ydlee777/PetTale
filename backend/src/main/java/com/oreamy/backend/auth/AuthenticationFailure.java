package com.oreamy.backend.auth;

public class AuthenticationFailure extends RuntimeException {
    private final String code;

    public AuthenticationFailure(String code) {
        super(code);
        this.code = code;
    }

    public String code() { return code; }
}
