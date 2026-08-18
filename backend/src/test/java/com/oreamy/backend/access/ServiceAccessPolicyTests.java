package com.oreamy.backend.access;

import static org.assertj.core.api.Assertions.assertThat;

import com.oreamy.backend.identity.ServiceUser;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import com.oreamy.backend.subscription.PaidEntitlementRepository;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ServiceAccessPolicyTests {
    private static final Instant DAY_ZERO = Instant.parse("2026-08-17T01:23:45Z");
    private final ServiceAccessPolicy policy = new ServiceAccessPolicy(Duration.ofDays(30), 3, 300);

    @Test void missingLegacyTrialDatesAreConservativelyFreeAfterMigrationBoundary() {
        var access = policy.resolve(user(), DAY_ZERO);
        assertThat(access.plan()).isEqualTo(ServicePlan.FREE);
        assertThat(access.trialEligible()).isFalse();
        assertThat(access.trialStartedAt()).isNull();
        assertThat(access.trialExpiresAt()).isNull();
        assertThat(access.monthlyAiLimit()).isEqualTo(3);
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

    @Test void trialAndFuturePremiumUseThreeHundredWhileFreeUsesThree() {
        assertThat(policy.monthlyLimit(ServicePlan.FREE)).isEqualTo(3);
        assertThat(policy.monthlyLimit(ServicePlan.PREMIUM_TRIAL)).isEqualTo(300);
        assertThat(policy.monthlyLimit(ServicePlan.PREMIUM)).isEqualTo(300);
    }

    @Test void paidPremiumPrecedesTrialAndFree() {
        var paid = mock(PaidEntitlementRepository.class);
        var user = user();
        when(paid.hasActiveEntitlement(user.getId(), DAY_ZERO)).thenReturn(true);
        var paidPolicy = new ServiceAccessPolicy(Duration.ofDays(30), 3, 300, paid);
        var access = paidPolicy.resolve(user, DAY_ZERO);
        assertThat(access.plan()).isEqualTo(ServicePlan.PREMIUM);
        assertThat(access.monthlyAiLimit()).isEqualTo(300);
    }

    private ServiceUser user() {
        return new ServiceUser(UUID.randomUUID(), "apple-subject", null, DAY_ZERO);
    }
}
