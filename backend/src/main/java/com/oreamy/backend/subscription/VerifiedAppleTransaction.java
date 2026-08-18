package com.oreamy.backend.subscription;

import java.time.Instant;
import java.util.UUID;

public record VerifiedAppleTransaction(
        String productId,
        String originalTransactionId,
        String transactionId,
        UUID appAccountToken,
        AppleEnvironment environment,
        Instant expiresAt,
        Instant revokedAt,
        String revocationReason,
        Instant signedAt) {
}
