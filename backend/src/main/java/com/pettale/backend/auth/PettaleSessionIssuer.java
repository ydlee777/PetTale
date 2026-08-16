package com.pettale.backend.auth;

import com.pettale.backend.identity.ServiceUser;
import java.time.Clock;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.stereotype.Component;

@Component
public class PettaleSessionIssuer {
    private final JwtEncoder encoder;
    private final Clock clock;
    private final String issuer;
    private final Duration lifetime;

    public PettaleSessionIssuer(JwtEncoder encoder, Clock clock,
            @Value("${pettale.session.issuer}") String issuer,
            @Value("${pettale.session.lifetime}") Duration lifetime) {
        this.encoder = encoder;
        this.clock = clock;
        this.issuer = issuer;
        this.lifetime = lifetime;
    }

    public IssuedSession issue(ServiceUser user) {
        var issuedAt = clock.instant();
        var expiresAt = issuedAt.plus(lifetime);
        var claims = JwtClaimsSet.builder()
                .issuer(issuer).issuedAt(issuedAt).expiresAt(expiresAt)
                .subject(user.getId().toString()).build();
        var header = JwsHeader.with(MacAlgorithm.HS256).build();
        return new IssuedSession(encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue(), expiresAt);
    }

    public record IssuedSession(String token, java.time.Instant expiresAt) {}
}
