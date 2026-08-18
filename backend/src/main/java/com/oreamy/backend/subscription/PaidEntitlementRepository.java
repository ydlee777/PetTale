package com.oreamy.backend.subscription;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface PaidEntitlementRepository extends JpaRepository<PaidEntitlement, UUID> {
    Optional<PaidEntitlement> findByOriginalTransactionId(String originalTransactionId);

    @Query("select count(e) > 0 from PaidEntitlement e where e.serviceUser.id = :userId and e.revokedAt is null and e.verifiedExpiresAt > :now")
    boolean hasActiveEntitlement(@Param("userId") UUID userId, @Param("now") Instant now);
}
