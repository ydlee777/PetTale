package com.oreamy.backend.subscription;

public interface AppleTransactionVerifier {
    VerifiedAppleTransaction verify(String signedTransaction);
}
