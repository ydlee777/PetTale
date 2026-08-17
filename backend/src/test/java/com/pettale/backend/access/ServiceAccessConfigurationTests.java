package com.pettale.backend.access;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import org.junit.jupiter.api.Test;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.io.ClassPathResource;
import org.springframework.mock.env.MockEnvironment;

class ServiceAccessConfigurationTests {
    @Test void approvedDefaultsAreThirtyDaysThreeFreeAndOneHundredPremium() throws IOException {
        var environment = environment();
        assertThat(environment.getProperty("pettale.trial.duration")).isEqualTo("P30D");
        assertThat(environment.getProperty("pettale.ai.free-monthly-request-limit")).isEqualTo("3");
        assertThat(environment.getProperty("pettale.ai.premium-monthly-request-limit")).isEqualTo("100");
    }

    @Test void environmentOverridesAllCommercialPolicyValues() throws IOException {
        var environment = new MockEnvironment()
                .withProperty("PETTALE_TRIAL_DURATION", "P14D")
                .withProperty("PETTALE_AI_FREE_MONTHLY_REQUEST_LIMIT", "9")
                .withProperty("PETTALE_AI_PREMIUM_MONTHLY_REQUEST_LIMIT", "999");
        addApplicationConfiguration(environment);
        assertThat(environment.getProperty("pettale.trial.duration")).isEqualTo("P14D");
        assertThat(environment.getProperty("pettale.ai.free-monthly-request-limit")).isEqualTo("9");
        assertThat(environment.getProperty("pettale.ai.premium-monthly-request-limit")).isEqualTo("999");
    }

    private static MockEnvironment environment() throws IOException {
        var environment = new MockEnvironment();
        addApplicationConfiguration(environment);
        return environment;
    }

    private static void addApplicationConfiguration(MockEnvironment environment) throws IOException {
        new YamlPropertySourceLoader().load("application.yml", new ClassPathResource("application.yml"))
                .forEach(environment.getPropertySources()::addLast);
    }
}
