package com.oreamy.backend.usage;

public class AiQuotaExceeded extends RuntimeException {
    public AiQuotaExceeded() { super("Monthly AI request allowance is exhausted"); }
}
