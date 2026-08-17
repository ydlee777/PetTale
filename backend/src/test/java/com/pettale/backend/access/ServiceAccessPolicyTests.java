package com.pettale.backend.access;

import static org.assertj.core.api.Assertions.assertThat;

import com.pettale.backend.identity.ServiceUser;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class ServiceAccessPolicyTests {
    private static final Instant DAY_ZERO = Instant.parse("2026-08-17T01:23:45Z");
    private final ServiceAccessPolicy policy = new ServiceAccessPolicy(Duration.ofDays(30), 3, 100);

    @Test void neverStartedUserIsTrialEligibleWithPremiumAllowance() {
        var access = policy.resolve(user(), DAY_ZERO);
        assertThat(access.plan()).isEqualTo(ServicePlan.PREMIUM_TRIAL);
        assertThat(access.trialEligible()).isTrue();
        assertThat(access.trialStartedAt()).isNull();
        assertThat(access.trialExpiresAt()).isNull();
        assertThat(access.monthlyAiLimit()).isEqualTo(100);
    }

    @Test void activeUntilButNotIncludingExactExpiration() {
        var user = user();
        user.activateTrialIfEligible(DAY_ZERO, Duration.ofDays(30));
        assertThat(policy.resolve(user, DAY_ZERO).plan()).isEqualTo(ServicePlan.PREMIUM_TRIAL);
        assertThat(policy.resolve(user, DAY_ZERO.plus(Duration.ofDays(29))).plan()).isEqualTo(ServicePlan.PREMIUM_TRIAL);
        assertThat(policy.resolve(user, DAY_ZERO.plus(Duration.ofDays(30))).plan()).isEqualTo(ServicePlan.FREE);
        assertThat(policy.resolve(user, DAY_ZERO.plus(Duration.ofDays(31))).plan()).isEqualTo(ServicePlan.FREE);
    }

    @Test void expirationDoesNotMutateHistoricalTrialDates() {
        var user = user();
        user.activateTrialIfEligible(DAY_ZERO, Duration.ofDays(30));
        var expired = policy.resolve(user, DAY_ZERO.plus(Duration.ofDays(31)));
        assertThat(expired.trialStartedAt()).isEqualTo(DAY_ZERO);
        assertThat(expired.trialExpiresAt()).isEqualTo(DAY_ZERO.plus(Duration.ofDays(30)));
        assertThat(expired.trialEligible()).isFalse();
        assertThat(expired.monthlyAiLimit()).isEqualTo(3);
    }

    @Test void laterActivationNeverResetsOrExtendsTrial() {
        var user = user();
        policy.activateTrialIfEligible(user, DAY_ZERO);
        policy.activateTrialIfEligible(user, DAY_ZERO.plus(Duration.ofDays(10)));
        assertThat(user.getTrialStartedAt()).isEqualTo(DAY_ZERO);
        assertThat(user.getTrialExpiresAt()).isEqualTo(DAY_ZERO.plus(Duration.ofDays(30)));
    }

    private ServiceUser user() {
        return new ServiceUser(UUID.randomUUID(), "apple-subject", null, DAY_ZERO);
    }
}
