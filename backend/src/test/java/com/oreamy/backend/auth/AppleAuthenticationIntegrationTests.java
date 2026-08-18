package com.oreamy.backend.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.when;

import com.oreamy.backend.identity.ServiceUserRepository;
import com.oreamy.backend.identity.ServiceUserService;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT, properties = {
        "spring.datasource.url=jdbc:h2:mem:oreamy;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
        "spring.datasource.username=sa", "spring.datasource.password=",
        "spring.jpa.hibernate.ddl-auto=validate",
        "oreamy.session.signing-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "oreamy.apple.audience=com.oreamy.app"
})
class AppleAuthenticationIntegrationTests {
    @LocalServerPort int port;
    @MockitoBean AppleIdentityVerifier verifier;
    @Autowired ServiceUserRepository users;
    @Autowired ServiceUserService serviceUsers;
    @Autowired JwtEncoder jwtEncoder;
    private final HttpClient client = HttpClient.newHttpClient();

    @BeforeEach void clean() { users.deleteAll(); }

    @Test void validCredentialCreatesUserAndIssuesSession() throws Exception {
        when(verifier.verify("valid", "nonce")).thenReturn(new VerifiedAppleIdentity("apple-1", "relay@example.com"));
        var response = post("/api/v1/auth/apple", "{\"identityToken\":\"valid\",\"nonce\":\"nonce\"}", null);
        assertThat(response.statusCode()).isEqualTo(200);
        assertThat(response.body()).contains("accessToken", "userId", "expiresAt");
        assertThat(Instant.parse(extract(response.body(), "expiresAt")))
                .isBetween(Instant.now().plusSeconds(29L * 24 * 60 * 60),
                        Instant.now().plusSeconds(31L * 24 * 60 * 60));
        assertThat(users.count()).isEqualTo(1);
        var created = users.findByAppleSubject("apple-1").orElseThrow();
        assertThat(created.getEmail()).isEqualTo("relay@example.com");
        assertThat(created.getTrialStartedAt()).isEqualTo(created.getCreatedAt());
        assertThat(created.getTrialExpiresAt()).isEqualTo(created.getCreatedAt().plusSeconds(30L * 24 * 60 * 60));
    }

    @Test void sameSubjectReturnsSameUserAndDifferentSubjectCreatesDifferentUser() throws Exception {
        when(verifier.verify("one", "nonce")).thenReturn(new VerifiedAppleIdentity("apple-1", null));
        when(verifier.verify("two", "nonce")).thenReturn(new VerifiedAppleIdentity("apple-2", null));
        var first = post("/api/v1/auth/apple", "{\"identityToken\":\"one\",\"nonce\":\"nonce\"}", null);
        var repeated = post("/api/v1/auth/apple", "{\"identityToken\":\"one\",\"nonce\":\"nonce\"}", null);
        var different = post("/api/v1/auth/apple", "{\"identityToken\":\"two\",\"nonce\":\"nonce\"}", null);
        assertThat(extract(first.body(), "userId")).isEqualTo(extract(repeated.body(), "userId"));
        assertThat(extract(different.body(), "userId")).isNotEqualTo(extract(first.body(), "userId"));
        assertThat(users.count()).isEqualTo(2);
    }

    @Test void missingCredentialIsRejectedAndAuthEndpointIsPublic() throws Exception {
        var response = post("/api/v1/auth/apple", "{\"identityToken\":\"\",\"nonce\":\"\"}", null);
        assertThat(response.statusCode()).isEqualTo(400);
        assertThat(response.body()).contains("invalid_request");
    }

    @Test void verifierFailureReturnsCleanUnauthorizedError() throws Exception {
        when(verifier.verify(anyString(), anyString())).thenThrow(new AuthenticationFailure("nonce_mismatch"));
        var response = post("/api/v1/auth/apple", "{\"identityToken\":\"bad\",\"nonce\":\"wrong\"}", null);
        assertThat(response.statusCode()).isEqualTo(401);
        assertThat(response.body()).contains("nonce_mismatch").doesNotContain("bad", "wrong");
    }

    @Test void healthIsPublicAndSessionEndpointRequiresValidOreamyToken() throws Exception {
        var health = get("/actuator/health", null);
        var anonymous = get("/api/v1/auth/session", null);
        var invalid = get("/api/v1/auth/session", "not-a-token");
        assertThat(health.statusCode()).isEqualTo(200);
        assertThat(anonymous.statusCode()).isEqualTo(401);
        assertThat(invalid.statusCode()).isEqualTo(401);
    }

    @Test void issuedOreamyTokenAuthenticatesInternalUserIdentity() throws Exception {
        when(verifier.verify("valid", "nonce")).thenReturn(new VerifiedAppleIdentity("apple-1", null));
        var login = post("/api/v1/auth/apple", "{\"identityToken\":\"valid\",\"nonce\":\"nonce\"}", null);
        var userId = extract(login.body(), "userId");
        var token = extract(login.body(), "accessToken");
        var session = get("/api/v1/auth/session", token);
        assertThat(session.statusCode()).isEqualTo(200);
        assertThat(session.body()).contains(userId);
    }

    @Test void simultaneousFirstLoginResolvesOneServiceUser() throws Exception {
        var ready = new CountDownLatch(2);
        var start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            var first = executor.submit(() -> { ready.countDown(); start.await(); return serviceUsers.resolve("apple-race", null).getId(); });
            var second = executor.submit(() -> { ready.countDown(); start.await(); return serviceUsers.resolve("apple-race", null).getId(); });
            assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
            start.countDown();
            assertThat(first.get(5, TimeUnit.SECONDS)).isEqualTo(second.get(5, TimeUnit.SECONDS));
        }
        assertThat(users.count()).isEqualTo(1);
    }

    @Test void expiredOreamySessionIsRejected() throws Exception {
        var now = Instant.now();
        var claims = JwtClaimsSet.builder()
                .issuer("oreamy-backend")
                .subject(UUID.randomUUID().toString())
                .issuedAt(now.minusSeconds(120))
                .expiresAt(now.minusSeconds(60))
                .build();
        var token = jwtEncoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
        assertThat(get("/api/v1/auth/session", token).statusCode()).isEqualTo(401);
    }

    private HttpResponse<String> post(String path, String body, String bearer) throws Exception {
        var builder = HttpRequest.newBuilder(uri(path)).header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(body));
        if (bearer != null) builder.header("Authorization", "Bearer " + bearer);
        return client.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }

    private HttpResponse<String> get(String path, String bearer) throws Exception {
        var builder = HttpRequest.newBuilder(uri(path)).GET();
        if (bearer != null) builder.header("Authorization", "Bearer " + bearer);
        return client.send(builder.build(), HttpResponse.BodyHandlers.ofString());
    }

    private URI uri(String path) { return URI.create("http://127.0.0.1:" + port + path); }

    private static String extract(String json, String field) {
        return json.replaceAll(".*\\\"" + field + "\\\":\\\"([^\\\"]+)\\\".*", "$1");
    }
}
