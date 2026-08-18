package com.oreamy.backend.access;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.oreamy.backend.identity.ServiceUser;
import com.oreamy.backend.identity.ServiceUserRepository;
import com.oreamy.backend.usage.AiFailureCategory;
import com.oreamy.backend.usage.AiOperation;
import com.oreamy.backend.usage.AiProviderMetadata;
import com.oreamy.backend.usage.AiQuotaExceeded;
import com.oreamy.backend.usage.AiUsageRepository;
import com.oreamy.backend.usage.AiUsageService;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executors;
import java.util.concurrent.TimeUnit;
import javax.sql.DataSource;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

@SpringBootTest(properties = {
        "spring.datasource.url=${OREAMY_TEST_DB_URL:jdbc:h2:mem:service-access;MODE=PostgreSQL;DB_CLOSE_DELAY=-1}",
        "spring.datasource.username=${OREAMY_TEST_DB_USERNAME:sa}",
        "spring.datasource.password=${OREAMY_TEST_DB_PASSWORD:}",
        "spring.jpa.hibernate.ddl-auto=validate",
        "oreamy.session.signing-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "oreamy.ai.free-monthly-request-limit=2",
        "oreamy.ai.premium-monthly-request-limit=5"
})
class ServiceAccessIntegrationTests {
    private static final Instant NOW = Instant.parse("2026-08-17T01:23:45Z");
    @Autowired AiUsageService service;
    @Autowired AiUsageRepository usages;
    @Autowired ServiceUserRepository users;
    @Autowired JwtEncoder jwtEncoder;
    @Autowired WebApplicationContext webContext;
    @Autowired DataSource dataSource;
    @MockitoBean Clock clock;
    private MockMvc mvc;

    @BeforeEach void setup() {
        usages.deleteAll();
        users.deleteAll();
        when(clock.instant()).thenReturn(NOW);
        mvc = MockMvcBuilders.webAppContextSetup(webContext)
                .apply(SecurityMockMvcConfigurers.springSecurity()).build();
    }

    @Test void aiSuccessDoesNotAlterExistingTrialDates() {
        var user = user("new-user");
        var startedAt = user.getTrialStartedAt();
        var expiresAt = user.getTrialExpiresAt();
        var usage = service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        service.succeed(usage.getId(), metadata());
        var saved = users.findById(user.getId()).orElseThrow();
        assertThat(saved.getTrialStartedAt()).isEqualTo(startedAt);
        assertThat(saved.getTrialExpiresAt()).isEqualTo(expiresAt);
    }

    @Test void aiFailureDoesNotAlterExistingTrialDates() {
        var user = user("retry-user");
        var startedAt = user.getTrialStartedAt();
        var expiresAt = user.getTrialExpiresAt();
        var failed = service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        service.fail(failed.getId(), AiFailureCategory.PROVIDER_ERROR);
        var saved = users.findById(user.getId()).orElseThrow();
        assertThat(saved.getTrialStartedAt()).isEqualTo(startedAt);
        assertThat(saved.getTrialExpiresAt()).isEqualTo(expiresAt);
    }

    @Test void laterSuccessDoesNotResetTrial() {
        var user = user("repeat-user");
        var first = service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        service.succeed(first.getId(), metadata());
        when(clock.instant()).thenReturn(NOW.plus(Duration.ofDays(5)));
        var later = service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        service.succeed(later.getId(), metadata());
        var saved = users.findById(user.getId()).orElseThrow();
        assertThat(saved.getTrialStartedAt()).isEqualTo(NOW);
        assertThat(saved.getTrialExpiresAt()).isEqualTo(NOW.plus(Duration.ofDays(30)));
    }

    @Test void trialUsesPremiumLimitAndExpiredTrialUsesFreeLimit() {
        var trial = user("trial-limit");
        for (int index = 0; index < 5; index++) service.reserve(trial.getId(), AiOperation.EVENT_EXTRACTION);
        assertThatThrownBy(() -> service.reserve(trial.getId(), AiOperation.EVENT_EXTRACTION))
                .isInstanceOf(AiQuotaExceeded.class);

        var free = new ServiceUser(UUID.randomUUID(), "free-limit", null, NOW.minus(Duration.ofDays(31)));
        free.activateTrialIfEligible(NOW.minus(Duration.ofDays(31)), Duration.ofDays(30));
        users.saveAndFlush(free);
        service.reserve(free.getId(), AiOperation.EVENT_EXTRACTION);
        service.reserve(free.getId(), AiOperation.EVENT_EXTRACTION);
        assertThatThrownBy(() -> service.reserve(free.getId(), AiOperation.EVENT_EXTRACTION))
                .isInstanceOf(AiQuotaExceeded.class);
    }

    @Test void statusEndpointUsesJwtOwnerAndAuthoritativeUsageCount() throws Exception {
        var caller = user("caller");
        var other = user("other");
        service.reserve(caller.getId(), AiOperation.EVENT_EXTRACTION);
        service.reserve(other.getId(), AiOperation.EVENT_EXTRACTION);
        var response = mvc.perform(MockMvcRequestBuilders.get("/api/v1/service-access")
                        .header("Authorization", "Bearer " + token(caller.getId())))
                .andReturn().getResponse();
        assertThat(response.getStatus()).isEqualTo(200);
        assertThat(response.getContentAsString()).contains(
                "\"plan\":\"PREMIUM_TRIAL\"", "\"trialEligible\":false",
                "\"monthlyAiLimit\":5", "\"monthlyAiUsed\":1", "\"monthlyAiRemaining\":4");
        assertThat(response.getContentAsString()).doesNotContain(other.getId().toString(), "apple_subject");
    }

    @Test void anonymousStatusIsUnauthorizedAndRemainingNeverNegative() throws Exception {
        assertThat(mvc.perform(MockMvcRequestBuilders.get("/api/v1/service-access"))
                .andReturn().getResponse().getStatus()).isEqualTo(401);
        var user = user("remaining");
        for (int index = 0; index < 5; index++) service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        assertThat(service.serviceAccess(user.getId()).remaining()).isZero();
    }

    @Test void utcMonthBoundaryAndUserIsolationRemainAuthoritative() {
        var first = user("month-first");
        var second = user("month-second");
        when(clock.instant()).thenReturn(Instant.parse("2026-07-31T23:59:59Z"));
        service.reserve(first.getId(), AiOperation.EVENT_EXTRACTION);
        when(clock.instant()).thenReturn(Instant.parse("2026-08-01T00:00:00Z"));
        service.reserve(first.getId(), AiOperation.EVENT_EXTRACTION);
        service.reserve(second.getId(), AiOperation.EVENT_EXTRACTION);
        assertThat(service.serviceAccess(first.getId()).used()).isEqualTo(1);
        assertThat(service.serviceAccess(second.getId()).used()).isEqualTo(1);
    }

    @Test void concurrentSuccessesDoNotChangeTrialDates() throws Exception {
        try (var connection = dataSource.getConnection()) {
            Assumptions.assumeTrue(connection.getMetaData().getDatabaseProductName().equals("PostgreSQL"));
        }
        var user = user("postgres-race");
        var first = service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        var second = service.reserve(user.getId(), AiOperation.EVENT_EXTRACTION);
        var ready = new CountDownLatch(2);
        var start = new CountDownLatch(1);
        try (var executor = Executors.newFixedThreadPool(2)) {
            var one = executor.submit(() -> { succeed(first.getId(), ready, start); return null; });
            var two = executor.submit(() -> { succeed(second.getId(), ready, start); return null; });
            assertThat(ready.await(5, TimeUnit.SECONDS)).isTrue();
            start.countDown();
            one.get(10, TimeUnit.SECONDS);
            two.get(10, TimeUnit.SECONDS);
        }
        var activated = users.findById(user.getId()).orElseThrow();
        assertThat(activated.getTrialStartedAt()).isEqualTo(NOW);
        assertThat(activated.getTrialExpiresAt()).isEqualTo(NOW.plus(Duration.ofDays(30)));
    }

    private void succeed(UUID usageId, CountDownLatch ready, CountDownLatch start) throws Exception {
        ready.countDown();
        start.await();
        service.succeed(usageId, metadata());
    }

    private ServiceUser user(String subject) {
        var user = new ServiceUser(UUID.randomUUID(), subject, null, NOW);
        user.activateTrialIfEligible(NOW, Duration.ofDays(30));
        return users.saveAndFlush(user);
    }

    private AiProviderMetadata metadata() {
        return new AiProviderMetadata("OPENAI", "gpt-5-mini", 10L, 5L, UUID.randomUUID().toString());
    }

    private String token(UUID userId) {
        var issuedAt = Instant.now();
        var claims = JwtClaimsSet.builder().issuer("oreamy-backend").subject(userId.toString())
                .issuedAt(issuedAt).expiresAt(issuedAt.plusSeconds(3600)).build();
        return jwtEncoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }
}
