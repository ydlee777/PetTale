package com.oreamy.backend.auth;

public interface AppleIdentityVerifier {
    VerifiedAppleIdentity verify(String identityToken, String originalNonce);
}
