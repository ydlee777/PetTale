package com.oreamy.backend.access;

import static org.assertj.core.api.Assertions.assertThat;

import java.sql.DriverManager;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.datasource.init.ResourceDatabasePopulator;
import org.springframework.jdbc.datasource.SimpleDriverDataSource;

class ServiceUserTrialMigrationTests {
    @Test void backfillsOnlyNullLegacyTrialsFromCreatedAt() throws Exception {
        var url = "jdbc:h2:mem:trial-migration-" + UUID.randomUUID()
                + ";MODE=PostgreSQL;DB_CLOSE_DELAY=-1";
        var dataSource = new SimpleDriverDataSource(new org.h2.Driver(), url, "sa", "");
        try (var connection = DriverManager.getConnection(url, "sa", "");
             var statement = connection.createStatement()) {
            statement.execute("""
                    CREATE TABLE service_user (
                        id UUID PRIMARY KEY,
                        created_at TIMESTAMP WITH TIME ZONE NOT NULL,
                        trial_started_at TIMESTAMP WITH TIME ZONE NULL,
                        trial_expires_at TIMESTAMP WITH TIME ZONE NULL
                    )
                    """);
            statement.execute("""
                    INSERT INTO service_user VALUES
                    ('00000000-0000-0000-0000-000000000001', TIMESTAMP WITH TIME ZONE '2026-01-01 00:00:00Z', NULL, NULL),
                    ('00000000-0000-0000-0000-000000000002', TIMESTAMP WITH TIME ZONE '2025-01-01 00:00:00Z',
                     TIMESTAMP WITH TIME ZONE '2026-02-01 00:00:00Z', TIMESTAMP WITH TIME ZONE '2026-03-03 00:00:00Z')
                    """);
        }

        new ResourceDatabasePopulator(new ClassPathResource(
                "db/migration/V5__backfill_service_user_trial_from_creation.sql")).execute(dataSource);

        try (var connection = dataSource.getConnection();
             var result = connection.createStatement().executeQuery(
                     "SELECT id, trial_started_at, trial_expires_at FROM service_user ORDER BY id")) {
            assertThat(result.next()).isTrue();
            assertThat(result.getObject("trial_started_at", Instant.class))
                    .isEqualTo(Instant.parse("2026-01-01T00:00:00Z"));
            assertThat(result.getObject("trial_expires_at", Instant.class))
                    .isEqualTo(Instant.parse("2026-01-31T00:00:00Z"));
            assertThat(result.next()).isTrue();
            assertThat(result.getObject("trial_started_at", Instant.class))
                    .isEqualTo(Instant.parse("2026-02-01T00:00:00Z"));
            assertThat(result.getObject("trial_expires_at", Instant.class))
                    .isEqualTo(Instant.parse("2026-03-03T00:00:00Z"));
        }
    }
}
