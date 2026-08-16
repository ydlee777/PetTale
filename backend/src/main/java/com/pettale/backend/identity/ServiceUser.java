package com.pettale.backend.identity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "service_user")
public class ServiceUser {
    @Id
    private UUID id;
    @Column(name = "apple_subject", nullable = false, unique = true, updatable = false)
    private String appleSubject;
    @Column(length = 320)
    private String email;
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    protected ServiceUser() {}

    public ServiceUser(UUID id, String appleSubject, String email, Instant now) {
        this.id = id;
        this.appleSubject = appleSubject;
        this.email = email;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getId() { return id; }
    public String getAppleSubject() { return appleSubject; }
    public String getEmail() { return email; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }

    public void captureVerifiedEmailIfMissing(String verifiedEmail, Instant now) {
        if (email == null && verifiedEmail != null && !verifiedEmail.isBlank()) {
            email = verifiedEmail;
            updatedAt = now;
        }
    }
}
