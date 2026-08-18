package com.oreamy.backend.subscription;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import com.oreamy.backend.identity.ServiceUser;
import com.oreamy.backend.identity.ServiceUserRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;

class PaidEntitlementServiceTests {
    private static final Instant NOW = Instant.parse("2026-08-18T12:00:00Z");
    private final UUID userId = UUID.randomUUID();
    private final AppleTransactionVerifier verifier = Mockito.mock(AppleTransactionVerifier.class);
    private final PaidEntitlementRepository entitlements = Mockito.mock(PaidEntitlementRepository.class);
    private final ServiceUserRepository users = Mockito.mock(ServiceUserRepository.class);
    private final PaidEntitlementService service = new PaidEntitlementService(
            verifier, entitlements, users, Clock.fixed(NOW, ZoneOffset.UTC));

    @BeforeEach void setup() {
        when(users.findById(userId)).thenReturn(Optional.of(new ServiceUser(userId, "apple-sub", null, NOW)));
        when(entitlements.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
    }

    @Test void monthlyAndAnnualVerifiedTransactionsPersistOnlyServiceMetadata() {
        for (String product : PaidEntitlementService.ALLOWED_PRODUCTS) {
            reset(entitlements);
            when(entitlements.save(any())).thenAnswer(invocation -> invocation.getArgument(0));
            when(entitlements.findByOriginalTransactionId(any())).thenReturn(Optional.empty());
            when(verifier.verify("signed")).thenReturn(transaction(product, userId, UUID.randomUUID().toString()));
            var result = service.synchronize(userId, "signed");
            assertThat(result.getProductId()).isEqualTo(product);
            assertThat(result.getAppAccountToken()).isEqualTo(userId);
            assertThat(result.getEnvironment()).isEqualTo(AppleEnvironment.SANDBOX);
        }
    }

    @Test void tokenlessMismatchAndUnknownProductAreRejected() {
        assertRejected(transaction(Oreamy(), null, "one"), "missing_app_account_token");
        assertRejected(transaction(Oreamy(), UUID.randomUUID(), "two"), "app_account_token_mismatch");
        assertRejected(transaction("unknown", userId, "three"), "unknown_product");
        verify(entitlements, never()).save(any());
    }

    @Test void expiredAndRevokedEvidenceIsPersistedButNeverActive() {
        for (var transaction : new VerifiedAppleTransaction[] {
                new VerifiedAppleTransaction(Oreamy(), "expired", "tx-expired", userId,
                        AppleEnvironment.PRODUCTION, NOW, null, null, NOW),
                new VerifiedAppleTransaction(Oreamy(), "revoked", "tx-revoked", userId,
                        AppleEnvironment.PRODUCTION, NOW.plusSeconds(100), NOW, "1", NOW) }) {
            when(verifier.verify("signed")).thenReturn(transaction);
            when(entitlements.findByOriginalTransactionId(transaction.originalTransactionId())).thenReturn(Optional.empty());
            assertThat(service.synchronize(userId, "signed").isActive(NOW)).isFalse();
        }
    }

    @Test void duplicateSynchronizationIsIdempotentAndCrossUserOwnershipIsRejected() {
        var verified = transaction(Oreamy(), userId, "original");
        var existing = new PaidEntitlement(UUID.randomUUID(), users.findById(userId).orElseThrow(), verified, NOW);
        when(verifier.verify("signed")).thenReturn(verified);
        when(entitlements.findByOriginalTransactionId("original")).thenReturn(Optional.of(existing));
        assertThat(service.synchronize(userId, "signed").getId()).isEqualTo(existing.getId());

        assertThatThrownBy(() -> service.synchronize(UUID.randomUUID(), "signed"))
                .isInstanceOf(EntitlementFailure.class)
                .hasMessage("app_account_token_mismatch");
    }

    private void assertRejected(VerifiedAppleTransaction transaction, String code) {
        when(verifier.verify("signed")).thenReturn(transaction);
        assertThatThrownBy(() -> service.synchronize(userId, "signed"))
                .isInstanceOf(EntitlementFailure.class).hasMessage(code);
    }

    private VerifiedAppleTransaction transaction(String product, UUID token, String original) {
        return new VerifiedAppleTransaction(product, original, "tx-" + original, token,
                AppleEnvironment.SANDBOX, NOW.plusSeconds(3600), null, null, NOW);
    }

    private String Oreamy() { return "com.oreamy.app.premium.monthly"; }
}
