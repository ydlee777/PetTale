package com.pettale.backend.auth;

import com.pettale.backend.identity.ServiceUserService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.time.Instant;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class AppleAuthenticationController {
    private final AppleIdentityVerifier verifier;
    private final ServiceUserService users;
    private final PettaleSessionIssuer sessions;

    public AppleAuthenticationController(AppleIdentityVerifier verifier, ServiceUserService users, PettaleSessionIssuer sessions) {
        this.verifier = verifier;
        this.users = users;
        this.sessions = sessions;
    }

    @PostMapping("/apple")
    public AuthenticationResponse authenticate(@Valid @RequestBody AppleAuthenticationRequest request) {
        var apple = verifier.verify(request.identityToken(), request.nonce());
        var user = users.resolve(apple.subject(), apple.email());
        var session = sessions.issue(user);
        return new AuthenticationResponse(user.getId(), session.token(), session.expiresAt());
    }

    @GetMapping("/session")
    public SessionResponse session(Authentication authentication) {
        return new SessionResponse(UUID.fromString(authentication.getName()));
    }

    @ExceptionHandler(AuthenticationFailure.class)
    @ResponseStatus(HttpStatus.UNAUTHORIZED)
    ErrorResponse authenticationFailure(AuthenticationFailure failure) {
        return new ErrorResponse(failure.code(), "Apple authentication failed.");
    }

    public record AppleAuthenticationRequest(@NotBlank String identityToken, @NotBlank String nonce) {}
    public record AuthenticationResponse(UUID userId, String accessToken, Instant expiresAt) {}
    public record SessionResponse(UUID userId) {}
    public record ErrorResponse(String code, String message) {}
}
