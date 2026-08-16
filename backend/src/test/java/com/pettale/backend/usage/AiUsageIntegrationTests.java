package com.pettale.backend.usage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.pettale.backend.ai.AiGatewayService;
import com.pettale.backend.identity.ServiceUser;
import com.pettale.backend.identity.ServiceUserRepository;
import java.time.Clock;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

@SpringBootTest(properties = {
        "spring.datasource.url=${PETTALE_TEST_DB_URL:jdbc:h2:mem:ai-usage;MODE=PostgreSQL;DB_CLOSE_DELAY=-1}",
        "spring.datasource.username=${PETTALE_TEST_DB_USERNAME:sa}",
        "spring.datasource.password=${PETTALE_TEST_DB_PASSWORD:}",
        "spring.jpa.hibernate.ddl-auto=validate",
        "pettale.session.signing-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "pettale.ai.monthly-request-limit=2"
})
@Import(AiUsageIntegrationTests.TestAiBoundaryConfiguration.class)
class AiUsageIntegrationTests {
    private static final Instant AUGUST = Instant.parse("2026-08-16T12:00:00Z");
    @Autowired AiUsageService service;
    @Autowired AiUsageRepository usages;
    @Autowired ServiceUserRepository users;
    @Autowired JwtEncoder jwtEncoder;
    @Autowired WebApplicationContext webContext;
    @MockitoBean Clock clock;
    private MockMvc mvc;

    @BeforeEach void clean() {
        usages.deleteAll();
        users.deleteAll();
        when(clock.instant()).thenReturn(AUGUST);
        mvc = MockMvcBuilders.webAppContextSetup(webContext)
                .apply(SecurityMockMvcConfigurers.springSecurity()).build();
    }

    @Test void reservationSuccessFailureAndMetadataLifecycle() {
        var user = user("apple-one");
        var succeeded = service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        service.succeed(succeeded.getId(), new AiProviderMetadata("OPENAI", "configured-model", 120L, 40L, "provider-1"));
        var saved = usages.findById(succeeded.getId()).orElseThrow();
        assertThat(saved.getStatus()).isEqualTo(AiUsageStatus.SUCCEEDED);
        assertThat(saved.getProvider()).isEqualTo("OPENAI");
        assertThat(saved.getModel()).isEqualTo("configured-model");
        assertThat(saved.getInputTokens()).isEqualTo(120L);
        assertThat(saved.getOutputTokens()).isEqualTo(40L);
        assertThat(saved.getProviderRequestId()).isEqualTo("provider-1");

        var failed = service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        service.fail(failed.getId(), AiFailureCategory.TIMEOUT);
        assertThat(usages.findById(failed.getId()).orElseThrow().getFailureCategory()).isEqualTo(AiFailureCategory.TIMEOUT);
    }

    @Test void failedUsageDoesNotConsumeQuotaButCountedUsageDoes() {
        var user = user("apple-one");
        var failed = service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        service.fail(failed.getId(), AiFailureCategory.PROVIDER_ERROR);
        service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        assertThatThrownBy(() -> service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION))
                .isInstanceOf(AiQuotaExceeded.class);
    }

    @Test void usersAndUtcCalendarMonthsAreIsolated() {
        var first = user("apple-one");
        var second = user("apple-two");
        when(clock.instant()).thenReturn(Instant.parse("2026-07-31T23:59:59Z"));
        service.reserve(first.getId(), AiOperation.EVENT_EXTRACTION);
        when(clock.instant()).thenReturn(Instant.parse("2026-08-01T00:00:00Z"));
        service.reserve(first.getId(), AiOperation.EVENT_EXTRACTION);
        service.reserve(first.getId(), AiOperation.EVENT_EXTRACTION);
        service.reserve(second.getId(), AiOperation.EVENT_EXTRACTION);
        assertThatThrownBy(() -> service.reserve(first.getId(), AiOperation.EVENT_EXTRACTION))
                .isInstanceOf(AiQuotaExceeded.class);
        assertThat(usages.count()).isEqualTo(4);
    }

    @Test void concurrentRequestsCannotBothTakeLastSlot() throws Exception {
        var user = user("apple-race");
        service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        var ready = new CountDownLatch(2);
        var start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            var first = executor.submit(() -> attemptReserve(user.getId(), ready, start));
            var second = executor.submit(() -> attemptReserve(user.getId(), ready, start));
            assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
            start.countDown();
            assertThat(first.get(5, TimeUnit.SECONDS) + second.get(5, TimeUnit.SECONDS)).isEqualTo(1);
        }
        assertThat(usages.count()).isEqualTo(2);
    }

    @Test void authenticatedBoundaryDerivesCallerFromJwtAndRejectsAnonymous() throws Exception {
        var caller = user("apple-caller");
        var other = user("apple-other");
        mvc.perform(MockMvcRequestBuilders.post("/test/ai/reserve").contentType("application/json")
                        .content("{\"userId\":\"" + other.getId() + "\"}"))
                .andExpect(result -> assertThat(result.getResponse().getStatus()).isEqualTo(401));

        mvc.perform(MockMvcRequestBuilders.post("/test/ai/reserve")
                        .header("Authorization", "Bearer " + token(caller.getId()))
                        .contentType("application/json").content("{\"userId\":\"" + other.getId() + "\"}"))
                .andExpect(result -> assertThat(result.getResponse().getStatus()).isEqualTo(200));
        assertThat(usages.findAll()).singleElement().satisfies(usage ->
                assertThat(usage.getServiceUserId()).isEqualTo(caller.getId()));
    }

    @Test void schemaStoresNoTranscriptPromptOrResponseFields() {
        assertThat(AiUsage.class.getDeclaredFields()).extracting(java.lang.reflect.Field::getName)
                .doesNotContain("transcript", "prompt", "response", "audio", "petId");
    }

    private int attemptReserve(UUID userId, CountDownLatch ready, CountDownLatch start) throws InterruptedException {
        ready.countDown();
        start.await();
        try { service.reserve(userId, AiOperation.EVENT_EXTRACTION); return 1; }
        catch (AiQuotaExceeded exhausted) { return 0; }
    }

    private ServiceUser user(String subject) {
        return users.saveAndFlush(new ServiceUser(UUID.randomUUID(), subject, null, AUGUST));
    }

    private String token(UUID userId) {
        var now = Instant.now();
        var claims = JwtClaimsSet.builder().issuer("pettale-backend").subject(userId.toString())
                .issuedAt(now).expiresAt(now.plusSeconds(3600)).build();
        return jwtEncoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }

    @TestConfiguration
    static class TestAiBoundaryConfiguration {
        @Bean TestAiBoundaryController testAiBoundaryController(AiGatewayService gateway) {
            return new TestAiBoundaryController(gateway);
        }
    }

    @RestController
    static class TestAiBoundaryController {
        private final AiGatewayService gateway;
        TestAiBoundaryController(AiGatewayService gateway) { this.gateway = gateway; }
        @PostMapping("/test/ai/reserve")
        String reserve(Authentication authentication, @RequestBody(required = false) String ignored) {
            return gateway.reserveEventExtraction(authentication).getId().toString();
        }
    }
}
