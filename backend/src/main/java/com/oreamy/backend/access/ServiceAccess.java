package com.oreamy.backend.access;

import java.time.Instant;

public record ServiceAccess(
        ServicePlan plan,
        Instant trialStartedAt,
        Instant trialExpiresAt,
        boolean trialEligible,
        int monthlyAiLimit) {}
