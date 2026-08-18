package com.oreamy.backend.subscription;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import tools.jackson.databind.JsonNode;
import java.time.Instant;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/subscriptions/apple")
public class PaidEntitlementController {
    private final PaidEntitlementService service;

    public PaidEntitlementController(PaidEntitlementService service) { this.service = service; }

    @PostMapping("/sync")
    SyncResponse synchronize(Authentication authentication, @Valid @RequestBody SyncRequest request) {
        if (request.hasForbiddenAuthority()) throw new EntitlementFailure("client_entitlement_authority_forbidden");
        var entitlement = service.synchronize(UUID.fromString(authentication.getName()), request.signedTransaction());
        return new SyncResponse(entitlement.getProductId(), entitlement.getVerifiedExpiresAt(), entitlement.isActive(Instant.now()));
    }

    @ExceptionHandler(EntitlementFailure.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    ErrorResponse failure(EntitlementFailure failure) { return new ErrorResponse(failure.code()); }

    public record SyncRequest(
            @NotBlank String signedTransaction,
            JsonNode userId,
            JsonNode appleSubject,
            JsonNode email,
            JsonNode isPremium,
            JsonNode expiresAt) {
        boolean hasForbiddenAuthority() {
            return userId != null || appleSubject != null || email != null || isPremium != null || expiresAt != null;
        }
    }
    public record SyncResponse(String productId, Instant expiresAt, boolean premium) {}
    public record ErrorResponse(String code) {}
}
