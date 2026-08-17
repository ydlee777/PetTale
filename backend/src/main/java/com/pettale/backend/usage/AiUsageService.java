package com.pettale.backend.usage;

import com.pettale.backend.access.ServiceAccess;
import com.pettale.backend.access.ServiceAccessPolicy;
import com.pettale.backend.identity.ServiceUserRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.Duration;
import java.time.ZoneOffset;
import java.time.temporal.TemporalAdjusters;
import java.util.EnumSet;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AiUsageService {
    private static final EnumSet<AiUsageStatus> COUNTED_STATUSES =
            EnumSet.of(AiUsageStatus.RESERVED, AiUsageStatus.SUCCEEDED);

    private final ServiceUserRepository users;
    private final AiUsageRepository usages;
    private final Clock clock;
    private final ServiceAccessPolicy accessPolicy;
    private final Duration reservationTimeout;

    public AiUsageService(ServiceUserRepository users, AiUsageRepository usages, Clock clock,
            ServiceAccessPolicy accessPolicy,
            @Value("${pettale.ai.reservation-timeout}") Duration reservationTimeout) {
        if (reservationTimeout.isNegative() || reservationTimeout.isZero()) {
            throw new IllegalArgumentException("AI reservation timeout must be positive");
        }
        this.users = users;
        this.usages = usages;
        this.clock = clock;
        this.accessPolicy = accessPolicy;
        this.reservationTimeout = reservationTimeout;
    }

    @Transactional
    public AiUsage reserve(UUID userId, AiOperation operation) {
        var user = users.findByIdForUpdate(userId).orElseThrow(() -> new IllegalArgumentException("Unknown service user"));
        var now = clock.instant();
        usages.findStale(userId, operation, AiUsageStatus.RESERVED, now.minus(reservationTimeout))
                .forEach(usage -> usage.fail(AiFailureCategory.STALE_RESERVATION, now));
        var window = utcMonth(now);
        var counted = usages.countInWindow(userId, operation, COUNTED_STATUSES, window.start(), window.end());
        var access = accessPolicy.resolve(user, now);
        if (counted >= access.monthlyAiLimit()) throw new AiQuotaExceeded();
        return usages.save(new AiUsage(UUID.randomUUID(), user, operation, now));
    }

    @Transactional
    public AiUsage succeed(UUID usageId, AiProviderMetadata metadata) {
        var usage = usages.findById(usageId).orElseThrow(() -> new IllegalArgumentException("Unknown AI usage"));
        var now = clock.instant();
        var user = users.findByIdForUpdate(usage.getServiceUserId())
                .orElseThrow(() -> new IllegalArgumentException("Unknown service user"));
        usage.succeed(metadata, now);
        accessPolicy.activateTrialIfEligible(user, now);
        return usage;
    }

    @Transactional
    public AiUsage fail(UUID usageId, AiFailureCategory category) {
        var usage = usages.findById(usageId).orElseThrow(() -> new IllegalArgumentException("Unknown AI usage"));
        usage.fail(category, clock.instant());
        return usage;
    }

    @Transactional(readOnly = true)
    public ServiceAccessUsage serviceAccess(UUID userId) {
        var user = users.findById(userId).orElseThrow(() -> new IllegalArgumentException("Unknown service user"));
        var now = clock.instant();
        var access = accessPolicy.resolve(user, now);
        var window = utcMonth(now);
        var used = usages.countInWindow(
                userId, AiOperation.EVENT_EXTRACTION, COUNTED_STATUSES, window.start(), window.end());
        return new ServiceAccessUsage(access, used, Math.max(0, access.monthlyAiLimit() - used));
    }

    static UsageWindow utcMonth(Instant instant) {
        var start = instant.atZone(ZoneOffset.UTC).with(TemporalAdjusters.firstDayOfMonth()).toLocalDate()
                .atStartOfDay(ZoneOffset.UTC).toInstant();
        return new UsageWindow(start, start.atZone(ZoneOffset.UTC).plusMonths(1).toInstant());
    }

    record UsageWindow(Instant start, Instant end) {}

    public record ServiceAccessUsage(ServiceAccess access, long used, long remaining) {}
}
