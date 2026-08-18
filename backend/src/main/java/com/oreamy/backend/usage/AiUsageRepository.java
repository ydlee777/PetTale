package com.oreamy.backend.usage;

import java.time.Instant;
import java.util.Collection;
import java.util.UUID;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface AiUsageRepository extends JpaRepository<AiUsage, UUID> {
    @Query("""
            select count(usage) from AiUsage usage
            where usage.serviceUser.id = :userId
              and usage.operation = :operation
              and usage.status in :statuses
              and usage.requestedAt >= :windowStart
              and usage.requestedAt < :windowEnd
            """)
    long countInWindow(
            @Param("userId") UUID userId,
            @Param("operation") AiOperation operation,
            @Param("statuses") Collection<AiUsageStatus> statuses,
            @Param("windowStart") Instant windowStart,
            @Param("windowEnd") Instant windowEnd);

    @Query("""
            select usage from AiUsage usage
            where usage.serviceUser.id = :userId
              and usage.operation = :operation
              and usage.status = :status
              and usage.requestedAt < :before
            """)
    List<AiUsage> findStale(
            @Param("userId") UUID userId,
            @Param("operation") AiOperation operation,
            @Param("status") AiUsageStatus status,
            @Param("before") Instant before);
}
