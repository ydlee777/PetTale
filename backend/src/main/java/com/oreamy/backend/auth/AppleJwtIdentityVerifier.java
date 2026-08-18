package com.oreamy.backend.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.stereotype.Component;

@Component
public class AppleJwtIdentityVerifier implements AppleIdentityVerifier {
    private final JwtDecoder decoder;

    public AppleJwtIdentityVerifier(@Qualifier("appleJwtDecoder") JwtDecoder decoder) {
        this.decoder = decoder;
    }

    @Override
    public VerifiedAppleIdentity verify(String identityToken, String originalNonce) {
        if (identityToken == null || identityToken.isBlank()) throw new AuthenticationFailure("missing_credential");
        if (originalNonce == null || originalNonce.isBlank()) throw new AuthenticationFailure("nonce_mismatch");
        final Jwt jwt;
        try {
            jwt = decoder.decode(identityToken);
        } catch (JwtException failure) {
            throw new AuthenticationFailure("invalid_apple_identity");
        }
        var subject = jwt.getSubject();
        if (subject == null || subject.isBlank()) throw new AuthenticationFailure("invalid_apple_identity");
        var tokenNonce = jwt.getClaimAsString("nonce");
        if (!MessageDigest.isEqual(sha256(originalNonce).getBytes(StandardCharsets.US_ASCII),
                String.valueOf(tokenNonce).getBytes(StandardCharsets.US_ASCII))) {
            throw new AuthenticationFailure("nonce_mismatch");
        }
        var emailVerified = jwt.getClaimAsBoolean("email_verified");
        return new VerifiedAppleIdentity(subject, Boolean.TRUE.equals(emailVerified) ? jwt.getClaimAsString("email") : null);
    }

    static String sha256(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        } catch (NoSuchAlgorithmException impossible) {
            throw new IllegalStateException(impossible);
        }
    }
}
