package com.oreamy.backend.access;

import java.time.Instant;

public record ServiceAccessResponse(
        ServicePlan plan,
        Instant trialStartedAt,
        Instant trialExpiresAt,
        boolean trialEligible,
        int monthlyAiLimit,
        long monthlyAiUsed,
        long monthlyAiRemaining) {}
