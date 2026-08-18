package com.oreamy.backend.subscription;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

import com.oreamy.backend.identity.ServiceUser;
import com.oreamy.backend.identity.ServiceUserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:paid-entitlement;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
        "spring.datasource.username=sa", "spring.datasource.password=",
        "oreamy.session.signing-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
})
class PaidEntitlementIntegrationTests {
    private static final Instant NOW = Instant.parse("2026-08-18T12:00:00Z");
    @Autowired WebApplicationContext context;
    @Autowired ServiceUserRepository users;
    @Autowired PaidEntitlementRepository entitlements;
    @Autowired JwtEncoder encoder;
    @MockitoBean AppleTransactionVerifier verifier;
    @MockitoBean Clock clock;
    private MockMvc mvc;

    @BeforeEach void setup() {
        entitlements.deleteAll();
        users.deleteAll();
        when(clock.instant()).thenReturn(NOW);
        mvc = MockMvcBuilders.webAppContextSetup(context)
                .apply(SecurityMockMvcConfigurers.springSecurity()).build();
    }

    @Test void anonymousCannotSynchronize() throws Exception {
        assertThat(post(null, "{\"signedTransaction\":\"signed\"}").getResponse().getStatus()).isEqualTo(401);
        assertThat(entitlements.count()).isZero();
    }

    @Test void authenticatedSignedEvidenceIsIdempotentAndStoresNoPrivatePetData() throws Exception {
        var user = user();
        when(verifier.verify("signed")).thenReturn(transaction(user.getId()));
        assertThat(post(token(user.getId()), "{\"signedTransaction\":\"signed\"}").getResponse().getStatus()).isEqualTo(200);
        assertThat(post(token(user.getId()), "{\"signedTransaction\":\"signed\"}").getResponse().getStatus()).isEqualTo(200);
        assertThat(entitlements.findAll()).singleElement().satisfies(entitlement -> {
            assertThat(entitlement.getServiceUserId()).isEqualTo(user.getId());
            assertThat(entitlement.getOriginalTransactionId()).isEqualTo("original-1");
            assertThat(entitlement.getProductId()).isEqualTo("com.oreamy.app.premium.monthly");
        });
    }

    @Test void forgedClientPremiumAuthorityIsRejected() throws Exception {
        var user = user();
        var response = post(token(user.getId()), "{\"signedTransaction\":\"signed\",\"isPremium\":true}").getResponse();
        assertThat(response.getStatus()).isEqualTo(400);
        assertThat(response.getContentAsString()).contains("client_entitlement_authority_forbidden");
        assertThat(entitlements.count()).isZero();
    }

    private ServiceUser user() {
        var user = new ServiceUser(UUID.randomUUID(), "apple-" + UUID.randomUUID(), null, NOW);
        return users.save(user);
    }

    private VerifiedAppleTransaction transaction(UUID userId) {
        return new VerifiedAppleTransaction("com.oreamy.app.premium.monthly", "original-1", "transaction-1",
                userId, AppleEnvironment.SANDBOX, NOW.plusSeconds(3600), null, null, NOW);
    }

    private org.springframework.test.web.servlet.MvcResult post(String token, String body) throws Exception {
        var request = MockMvcRequestBuilders.post("/api/v1/subscriptions/apple/sync")
                .contentType("application/json").content(body);
        if (token != null) request.header("Authorization", "Bearer " + token);
        return mvc.perform(request).andReturn();
    }

    private String token(UUID userId) {
        var header = JwsHeader.with(MacAlgorithm.HS256).build();
        var claims = JwtClaimsSet.builder().issuer("oreamy-backend").subject(userId.toString())
                .issuedAt(NOW).expiresAt(NOW.plusSeconds(86_400)).build();
        return encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }
}
