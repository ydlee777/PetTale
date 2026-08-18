package com.oreamy.backend.subscription;

import com.oreamy.backend.identity.ServiceUser;
import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "paid_entitlement")
public class PaidEntitlement {
    @Id private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "service_user_id", nullable = false, updatable = false)
    private ServiceUser serviceUser;
    @Column(name = "product_id", nullable = false, length = 128) private String productId;
    @Column(name = "original_transaction_id", nullable = false, unique = true, updatable = false, length = 128)
    private String originalTransactionId;
    @Column(name = "latest_transaction_id", nullable = false, unique = true, length = 128) private String latestTransactionId;
    @Column(name = "app_account_token", nullable = false, updatable = false) private UUID appAccountToken;
    @Enumerated(EnumType.STRING)
    @Column(name = "apple_environment", nullable = false, updatable = false, length = 16) private AppleEnvironment environment;
    @Column(name = "verified_expires_at", nullable = false) private Instant verifiedExpiresAt;
    @Column(name = "revoked_at") private Instant revokedAt;
    @Column(name = "revocation_reason", length = 64) private String revocationReason;
    @Column(name = "apple_signed_at", nullable = false) private Instant appleSignedAt;
    @Column(name = "last_verified_at", nullable = false) private Instant lastVerifiedAt;
    @Column(name = "created_at", nullable = false, updatable = false) private Instant createdAt;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;

    protected PaidEntitlement() {}

    PaidEntitlement(UUID id, ServiceUser user, VerifiedAppleTransaction transaction, Instant now) {
        this.id = id;
        this.serviceUser = user;
        this.originalTransactionId = transaction.originalTransactionId();
        this.appAccountToken = transaction.appAccountToken();
        this.environment = transaction.environment();
        this.createdAt = now;
        apply(transaction, now);
    }

    void apply(VerifiedAppleTransaction transaction, Instant now) {
        if (appleSignedAt != null && transaction.signedAt().isBefore(appleSignedAt)) {
            lastVerifiedAt = now;
            updatedAt = now;
            return;
        }
        productId = transaction.productId();
        latestTransactionId = transaction.transactionId();
        verifiedExpiresAt = transaction.expiresAt();
        revokedAt = transaction.revokedAt();
        revocationReason = transaction.revocationReason();
        appleSignedAt = transaction.signedAt();
        lastVerifiedAt = now;
        updatedAt = now;
    }

    public UUID getId() { return id; }
    public UUID getServiceUserId() { return serviceUser.getId(); }
    public String getProductId() { return productId; }
    public String getOriginalTransactionId() { return originalTransactionId; }
    public String getLatestTransactionId() { return latestTransactionId; }
    public UUID getAppAccountToken() { return appAccountToken; }
    public AppleEnvironment getEnvironment() { return environment; }
    public Instant getVerifiedExpiresAt() { return verifiedExpiresAt; }
    public Instant getRevokedAt() { return revokedAt; }
    public Instant getLastVerifiedAt() { return lastVerifiedAt; }
    public boolean isActive(Instant now) { return revokedAt == null && verifiedExpiresAt.isAfter(now); }
}
