package com.oreamy.backend.usage;

import com.oreamy.backend.identity.ServiceUser;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "ai_usage")
public class AiUsage {
    @Id private UUID id;
    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "service_user_id", nullable = false, updatable = false)
    private ServiceUser serviceUser;
    @Enumerated(EnumType.STRING) @Column(nullable = false, updatable = false, length = 64)
    private AiOperation operation;
    @Enumerated(EnumType.STRING) @Column(nullable = false, length = 32)
    private AiUsageStatus status;
    @Column(name = "requested_at", nullable = false, updatable = false)
    private Instant requestedAt;
    @Column(name = "completed_at") private Instant completedAt;
    @Column(length = 64) private String provider;
    @Column(length = 255) private String model;
    @Column(name = "input_tokens") private Long inputTokens;
    @Column(name = "output_tokens") private Long outputTokens;
    @Column(name = "provider_request_id", length = 255) private String providerRequestId;
    @Enumerated(EnumType.STRING) @Column(name = "failure_category", length = 64)
    private AiFailureCategory failureCategory;

    protected AiUsage() {}

    AiUsage(UUID id, ServiceUser serviceUser, AiOperation operation, Instant requestedAt) {
        this.id = id;
        this.serviceUser = serviceUser;
        this.operation = operation;
        this.status = AiUsageStatus.RESERVED;
        this.requestedAt = requestedAt;
    }

    void succeed(AiProviderMetadata metadata, Instant completedAt) {
        requireReserved();
        metadata.validate();
        status = AiUsageStatus.SUCCEEDED;
        this.completedAt = completedAt;
        provider = metadata.provider();
        model = metadata.model();
        inputTokens = metadata.inputTokens();
        outputTokens = metadata.outputTokens();
        providerRequestId = metadata.providerRequestId();
    }

    void fail(AiFailureCategory category, Instant completedAt) {
        requireReserved();
        status = AiUsageStatus.FAILED;
        failureCategory = category;
        this.completedAt = completedAt;
    }

    private void requireReserved() {
        if (status != AiUsageStatus.RESERVED) throw new IllegalStateException("AI usage is already completed");
    }

    public UUID getId() { return id; }
    public UUID getServiceUserId() { return serviceUser.getId(); }
    public AiOperation getOperation() { return operation; }
    public AiUsageStatus getStatus() { return status; }
    public Instant getRequestedAt() { return requestedAt; }
    public Instant getCompletedAt() { return completedAt; }
    public String getProvider() { return provider; }
    public String getModel() { return model; }
    public Long getInputTokens() { return inputTokens; }
    public Long getOutputTokens() { return outputTokens; }
    public String getProviderRequestId() { return providerRequestId; }
    public AiFailureCategory getFailureCategory() { return failureCategory; }
}
