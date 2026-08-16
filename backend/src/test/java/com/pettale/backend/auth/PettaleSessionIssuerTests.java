package com.pettale.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.nimbusds.jose.jwk.source.ImmutableSecret;
import com.pettale.backend.identity.ServiceUser;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.UUID;
import javax.crypto.spec.SecretKeySpec;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder;

class PettaleSessionIssuerTests {
    private static final Instant NOW = Instant.parse("2026-08-16T00:00:00Z");
    private final ServiceUser user = new ServiceUser(UUID.randomUUID(), "apple-subject", null, NOW);
    private final NimbusJwtEncoder encoder = new NimbusJwtEncoder(new ImmutableSecret<>(
            new SecretKeySpec(new byte[32], "HmacSHA256")));

    @Test void thirtyDayLifetimeProducesThirtyDayExpiration() {
        var issuer = new PettaleSessionIssuer(encoder, Clock.fixed(NOW, ZoneOffset.UTC), "pettale-backend", Duration.ofDays(30));
        assertThat(issuer.issue(user).expiresAt()).isEqualTo(NOW.plus(Duration.ofDays(30)));
    }

    @Test void configuredCustomLifetimeOverridesDefault() {
        var issuer = new PettaleSessionIssuer(encoder, Clock.fixed(NOW, ZoneOffset.UTC), "pettale-backend", Duration.ofHours(2));
        assertThat(issuer.issue(user).expiresAt()).isEqualTo(NOW.plus(Duration.ofHours(2)));
    }
}
