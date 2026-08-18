package com.oreamy.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jose.jwk.RSAKey;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import java.security.KeyPairGenerator;
import java.time.Instant;
import java.util.Date;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtIssuerValidator;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

class AppleJwtIdentityVerifierTests {
    private RSAKey signingKey;
    private AppleJwtIdentityVerifier verifier;

    @BeforeEach void setUp() throws Exception {
        var pair = KeyPairGenerator.getInstance("RSA");
        pair.initialize(2048);
        var keyPair = pair.generateKeyPair();
        signingKey = new RSAKey.Builder((java.security.interfaces.RSAPublicKey) keyPair.getPublic())
                .privateKey((java.security.interfaces.RSAPrivateKey) keyPair.getPrivate()).keyID("test").build();
        var decoder = NimbusJwtDecoder.withPublicKey(signingKey.toRSAPublicKey()).build();
        OAuth2TokenValidator<Jwt> audience = jwt -> jwt.getAudience().contains("com.oreamy.app")
                ? OAuth2TokenValidatorResult.success()
                : OAuth2TokenValidatorResult.failure(new OAuth2Error("invalid_token"));
        decoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(
                JwtValidators.createDefault(), new JwtIssuerValidator("https://appleid.apple.com"), audience));
        verifier = new AppleJwtIdentityVerifier(decoder);
    }

    @Test void verifiesSignatureIssuerAudienceExpirationSubjectNonceAndVerifiedEmail() throws Exception {
        var identity = verifier.verify(token("https://appleid.apple.com", "com.oreamy.app", Instant.now().plusSeconds(60), "nonce"), "nonce");
        assertThat(identity.subject()).isEqualTo("apple-subject");
        assertThat(identity.email()).isEqualTo("relay@example.com");
    }

    @Test void invalidSignatureIsRejected() throws Exception {
        var other = KeyPairGenerator.getInstance("RSA"); other.initialize(2048);
        var pair = other.generateKeyPair();
        var wrong = new RSAKey.Builder((java.security.interfaces.RSAPublicKey) pair.getPublic())
                .privateKey((java.security.interfaces.RSAPrivateKey) pair.getPrivate()).build();
        assertRejected(token(wrong, "https://appleid.apple.com", "com.oreamy.app", Instant.now().plusSeconds(60), "nonce"));
    }

    @Test void invalidIssuerIsRejected() throws Exception { assertRejected(token("https://attacker.example", "com.oreamy.app", Instant.now().plusSeconds(60), "nonce")); }
    @Test void invalidAudienceIsRejected() throws Exception { assertRejected(token("https://appleid.apple.com", "wrong", Instant.now().plusSeconds(60), "nonce")); }
    @Test void expiredTokenIsRejected() throws Exception { assertRejected(token("https://appleid.apple.com", "com.oreamy.app", Instant.now().minusSeconds(60), "nonce")); }

    @Test void nonceMismatchIsRejected() throws Exception {
        assertThatThrownBy(() -> verifier.verify(token("https://appleid.apple.com", "com.oreamy.app", Instant.now().plusSeconds(60), "nonce"), "other"))
                .isInstanceOf(AuthenticationFailure.class).hasMessage("nonce_mismatch");
    }

    private void assertRejected(String token) {
        assertThatThrownBy(() -> verifier.verify(token, "nonce"))
                .isInstanceOf(AuthenticationFailure.class).hasMessage("invalid_apple_identity");
    }

    private String token(String issuer, String audience, Instant expiration, String nonce) throws Exception {
        return token(signingKey, issuer, audience, expiration, nonce);
    }

    private String token(RSAKey key, String issuer, String audience, Instant expiration, String nonce) throws Exception {
        var claims = new JWTClaimsSet.Builder().issuer(issuer).audience(List.of(audience))
                .subject("apple-subject").expirationTime(Date.from(expiration)).issueTime(new Date())
                .claim("nonce", AppleJwtIdentityVerifier.sha256(nonce))
                .claim("email", "relay@example.com").claim("email_verified", true).build();
        var jwt = new SignedJWT(new JWSHeader.Builder(JWSAlgorithm.RS256).keyID("test").build(), claims);
        jwt.sign(new RSASSASigner(key));
        return jwt.serialize();
    }
}
