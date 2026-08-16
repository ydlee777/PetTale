package com.pettale.backend.ai;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import org.junit.jupiter.api.Test;
import org.springframework.boot.env.YamlPropertySourceLoader;
import org.springframework.core.io.ClassPathResource;
import org.springframework.mock.env.MockEnvironment;

class ExtractionConfigurationTests {
    @Test void approvedExtractionDefaultsAreLowReasoningAndLowVerbosity() throws IOException {
        var environment = environment();

        assertThat(environment.getProperty("pettale.ai.extraction-model")).isEqualTo("gpt-5-mini");
        assertThat(environment.getProperty("pettale.ai.reasoning-effort")).isEqualTo("low");
        assertThat(environment.getProperty("pettale.ai.text-verbosity")).isEqualTo("low");
    }

    @Test void environmentCanOverrideAllExtractionSettings() throws IOException {
        var environment = new MockEnvironment()
                .withProperty("PETTALE_EXTRACTION_MODEL", "test-model-alias")
                .withProperty("PETTALE_EXTRACTION_REASONING_EFFORT", "high")
                .withProperty("PETTALE_EXTRACTION_TEXT_VERBOSITY", "medium");
        addApplicationConfiguration(environment);

        assertThat(environment.getProperty("pettale.ai.extraction-model")).isEqualTo("test-model-alias");
        assertThat(environment.getProperty("pettale.ai.reasoning-effort")).isEqualTo("high");
        assertThat(environment.getProperty("pettale.ai.text-verbosity")).isEqualTo("medium");
    }

    private static MockEnvironment environment() throws IOException {
        var environment = new MockEnvironment();
        addApplicationConfiguration(environment);
        return environment;
    }

    private static void addApplicationConfiguration(MockEnvironment environment) throws IOException {
        var sources = new YamlPropertySourceLoader().load(
                "application.yml", new ClassPathResource("application.yml"));
        sources.forEach(environment.getPropertySources()::addLast);
    }
}
