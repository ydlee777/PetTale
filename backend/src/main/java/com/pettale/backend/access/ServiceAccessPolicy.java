package com.pettale.backend.access;

import com.pettale.backend.identity.ServiceUser;
import java.time.Duration;
import java.time.Instant;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class ServiceAccessPolicy {
    private final Duration trialDuration;
    private final int freeMonthlyLimit;
    private final int premiumMonthlyLimit;

    public ServiceAccessPolicy(
            @Value("${pettale.trial.duration}") Duration trialDuration,
            @Value("${pettale.ai.free-monthly-request-limit}") int freeMonthlyLimit,
            @Value("${pettale.ai.premium-monthly-request-limit}") int premiumMonthlyLimit) {
        if (trialDuration.isNegative() || trialDuration.isZero()) {
            throw new IllegalArgumentException("Trial duration must be positive");
        }
        if (freeMonthlyLimit < 0 || premiumMonthlyLimit < 0) {
            throw new IllegalArgumentException("Monthly AI request limits must be nonnegative");
        }
        this.trialDuration = trialDuration;
        this.freeMonthlyLimit = freeMonthlyLimit;
        this.premiumMonthlyLimit = premiumMonthlyLimit;
    }

    public ServiceAccess resolve(ServiceUser user, Instant now) {
        var startedAt = user.getTrialStartedAt();
        var expiresAt = user.getTrialExpiresAt();
        if (startedAt == null && expiresAt == null) {
            return new ServiceAccess(ServicePlan.PREMIUM_TRIAL, null, null, true, premiumMonthlyLimit);
        }
        if (startedAt != null && expiresAt != null && now.isBefore(expiresAt)) {
            return new ServiceAccess(ServicePlan.PREMIUM_TRIAL, startedAt, expiresAt, false, premiumMonthlyLimit);
        }
        return new ServiceAccess(ServicePlan.FREE, startedAt, expiresAt, false, freeMonthlyLimit);
    }

    public void activateTrialIfEligible(ServiceUser user, Instant activationInstant) {
        user.activateTrialIfEligible(activationInstant, trialDuration);
    }
}
