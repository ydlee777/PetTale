package com.oreamy.backend.access;

import com.oreamy.backend.identity.ServiceUser;
import com.oreamy.backend.subscription.PaidEntitlementRepository;
import java.time.Duration;
import java.time.Instant;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.beans.factory.annotation.Autowired;

@Component
public class ServiceAccessPolicy {
    private final int freeMonthlyLimit;
    private final int premiumMonthlyLimit;
    private final PaidEntitlementRepository paidEntitlements;

    @Autowired
    public ServiceAccessPolicy(
            @Value("${oreamy.trial.duration}") Duration trialDuration,
            @Value("${oreamy.ai.free-monthly-request-limit}") int freeMonthlyLimit,
            @Value("${oreamy.ai.premium-monthly-request-limit}") int premiumMonthlyLimit,
            PaidEntitlementRepository paidEntitlements) {
        if (trialDuration.isNegative() || trialDuration.isZero()) {
            throw new IllegalArgumentException("Trial duration must be positive");
        }
        if (freeMonthlyLimit < 0 || premiumMonthlyLimit < 0) {
            throw new IllegalArgumentException("Monthly AI request limits must be nonnegative");
        }
        this.freeMonthlyLimit = freeMonthlyLimit;
        this.premiumMonthlyLimit = premiumMonthlyLimit;
        this.paidEntitlements = paidEntitlements;
    }

    ServiceAccessPolicy(Duration trialDuration, int freeMonthlyLimit, int premiumMonthlyLimit) {
        this(trialDuration, freeMonthlyLimit, premiumMonthlyLimit, null);
    }

    public ServiceAccess resolve(ServiceUser user, Instant now) {
        if (paidEntitlements != null && paidEntitlements.hasActiveEntitlement(user.getId(), now)) {
            return new ServiceAccess(ServicePlan.PREMIUM, user.getTrialStartedAt(), user.getTrialExpiresAt(), false,
                    premiumMonthlyLimit);
        }
        var startedAt = user.getTrialStartedAt();
        var expiresAt = user.getTrialExpiresAt();
        if (startedAt == null && expiresAt == null) {
            return new ServiceAccess(ServicePlan.FREE, null, null, false, freeMonthlyLimit);
        }
        if (startedAt != null && expiresAt != null && now.isBefore(expiresAt)) {
            return new ServiceAccess(ServicePlan.PREMIUM_TRIAL, startedAt, expiresAt, false,
                    monthlyLimit(ServicePlan.PREMIUM_TRIAL));
        }
        return new ServiceAccess(ServicePlan.FREE, startedAt, expiresAt, false, freeMonthlyLimit);
    }

    int monthlyLimit(ServicePlan plan) {
        return plan == ServicePlan.FREE ? freeMonthlyLimit : premiumMonthlyLimit;
    }
}
