package com.oreamy.backend.subscription;

import com.oreamy.backend.identity.ServiceUserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PaidEntitlementService {
    static final Set<String> ALLOWED_PRODUCTS = Set.of(
            "com.oreamy.app.premium.monthly",
            "com.oreamy.app.premium.annual");

    private final AppleTransactionVerifier verifier;
    private final PaidEntitlementRepository entitlements;
    private final ServiceUserRepository users;
    private final Clock clock;

    public PaidEntitlementService(AppleTransactionVerifier verifier, PaidEntitlementRepository entitlements,
            ServiceUserRepository users, Clock clock) {
        this.verifier = verifier;
        this.entitlements = entitlements;
        this.users = users;
        this.clock = clock;
    }

    @Transactional
    public PaidEntitlement synchronize(UUID authenticatedUserId, String signedTransaction) {
        if (signedTransaction == null || signedTransaction.isBlank()) throw new EntitlementFailure("missing_signed_transaction");
        var transaction = verifier.verify(signedTransaction);
        if (!ALLOWED_PRODUCTS.contains(transaction.productId())) throw new EntitlementFailure("unknown_product");
        if (transaction.appAccountToken() == null) throw new EntitlementFailure("missing_app_account_token");
        if (!authenticatedUserId.equals(transaction.appAccountToken())) throw new EntitlementFailure("app_account_token_mismatch");
        if (transaction.originalTransactionId() == null || transaction.originalTransactionId().isBlank()
                || transaction.transactionId() == null || transaction.transactionId().isBlank()
                || transaction.expiresAt() == null || transaction.signedAt() == null) {
            throw new EntitlementFailure("invalid_transaction");
        }
        Instant now = clock.instant();
        var existing = entitlements.findByOriginalTransactionId(transaction.originalTransactionId());
        if (existing.isPresent() && !existing.get().getServiceUserId().equals(authenticatedUserId)) {
            throw new EntitlementFailure("transaction_owned_by_another_user");
        }
        var entitlement = existing.orElseGet(() -> new PaidEntitlement(
                UUID.randomUUID(), users.findById(authenticatedUserId).orElseThrow(() -> new EntitlementFailure("unknown_user")), transaction, now));
        if (existing.isPresent()) entitlement.apply(transaction, now);
        return entitlements.save(entitlement);
    }
}
