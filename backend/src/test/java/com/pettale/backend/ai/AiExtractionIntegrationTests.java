package com.pettale.backend.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.pettale.backend.identity.ServiceUser;
import com.pettale.backend.identity.ServiceUserRepository;
import com.pettale.backend.usage.AiFailureCategory;
import com.pettale.backend.usage.AiUsageRepository;
import com.pettale.backend.usage.AiUsageStatus;
import java.time.Clock;
import java.time.Instant;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
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
        "spring.datasource.url=jdbc:h2:mem:ai-extraction;MODE=PostgreSQL;DB_CLOSE_DELAY=-1",
        "spring.datasource.username=sa",
        "spring.datasource.password=",
        "pettale.session.signing-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=",
        "pettale.ai.monthly-request-limit=1"
})
class AiExtractionIntegrationTests {
    private static final Instant NOW = Instant.parse("2026-08-16T12:00:00Z");
    @Autowired WebApplicationContext webContext;
    @Autowired ServiceUserRepository users;
    @Autowired AiUsageRepository usages;
    @Autowired JwtEncoder jwtEncoder;
    @MockitoBean AiProvider provider;
    @MockitoBean Clock clock;
    private MockMvc mvc;

    @BeforeEach void setup() {
        usages.deleteAll();
        users.deleteAll();
        reset(provider);
        when(clock.instant()).thenReturn(NOW);
        mvc = MockMvcBuilders.webAppContextSetup(webContext)
                .apply(SecurityMockMvcConfigurers.springSecurity()).build();
    }

    @Test void anonymousRequestIsRejected() throws Exception {
        assertThat(perform(null, validRequest()).getResponse().getStatus()).isEqualTo(401);
        verify(provider, never()).extractEvents(any());
    }

    @Test void authenticatedRequestReservesBeforeProviderAndRecordsSuccessMetadata() throws Exception {
        var user = user("caller");
        doAnswer(invocation -> {
            assertThat(usages.findAll()).singleElement().satisfies(usage -> {
                assertThat(usage.getStatus()).isEqualTo(AiUsageStatus.RESERVED);
                assertThat(usage.getServiceUserId()).isEqualTo(user.getId());
            });
            return result(events(EventCategory.WEIGHT));
        }).when(provider).extractEvents(any());

        var response = perform(token(user.getId()), validRequest()).getResponse();
        assertThat(response.getStatus()).isEqualTo(200);
        assertThat(response.getContentAsString()).contains("\"schemaVersion\":\"1\"", "BODY_WEIGHT", "6.2");
        verify(provider).extractEvents(any());
        assertThat(usages.findAll()).singleElement().satisfies(usage -> {
            assertThat(usage.getStatus()).isEqualTo(AiUsageStatus.SUCCEEDED);
            assertThat(usage.getProvider()).isEqualTo("OPENAI");
            assertThat(usage.getModel()).isEqualTo("gpt-5-mini-2025-08-07");
            assertThat(usage.getInputTokens()).isEqualTo(100);
            assertThat(usage.getOutputTokens()).isEqualTo(40);
            assertThat(usage.getProviderRequestId()).isEqualTo("resp_test");
        });
    }

    @Test void quotaExceededDoesNotCallProviderAgain() throws Exception {
        var user = user("quota");
        when(provider.extractEvents(any())).thenReturn(result(events(EventCategory.WEIGHT)));
        assertThat(perform(token(user.getId()), validRequest()).getResponse().getStatus()).isEqualTo(200);
        assertThat(perform(token(user.getId()), validRequest()).getResponse().getStatus()).isEqualTo(429);
        verify(provider).extractEvents(any());
    }

    @Test void multipleEventsAndEveryAllowedCategoryAreMapped() throws Exception {
        var user = user("categories");
        when(provider.extractEvents(any())).thenReturn(result(events(EventCategory.values())));
        var response = perform(token(user.getId()), validRequest()).getResponse();
        assertThat(response.getStatus()).isEqualTo(200);
        for (var category : EventCategory.values()) assertThat(response.getContentAsString()).contains(category.name());
    }

    @Test void invalidProviderValuesAreRejectedAndUsageFailed() throws Exception {
        assertInvalid(new ExtractedEventDraft(EventCategory.HEALTH, "vomiting", NOW, null, null, 1, null, null));
        assertInvalid(new ExtractedEventDraft(EventCategory.HEALTH, "VOMITING", NOW, null, null, -1, null, null));
        assertInvalid(new ExtractedEventDraft(EventCategory.ACTIVITY, "PLAY", NOW, null, null, null, -1, null));
        assertInvalid(new ExtractedEventDraft(EventCategory.WEIGHT, "BODY_WEIGHT", NOW, Double.NaN, "KG", null, null, null));
        assertInvalid(new ExtractedEventDraft(EventCategory.OTHER, null, null, null, null, null, null, null));
    }

    @Test void emptyOrWrongVersionResultIsRejected() throws Exception {
        assertInvalidResult(new AiProvider.ExtractionResult("OPENAI", "model", 1, 1, "id", "1", List.of()));
        assertInvalidResult(new AiProvider.ExtractionResult("OPENAI", "model", 1, 1, "id", "2", events(EventCategory.OTHER)));
    }

    @Test void providerFailuresReturnSafeErrorsAndFinalizeUsage() throws Exception {
        assertFailure(ProviderFailure.Kind.TIMEOUT, 504, AiFailureCategory.TIMEOUT);
        assertFailure(ProviderFailure.Kind.RATE_LIMIT, 503, AiFailureCategory.RATE_LIMIT);
        assertFailure(ProviderFailure.Kind.ERROR, 502, AiFailureCategory.PROVIDER_ERROR);
        assertFailure(ProviderFailure.Kind.INVALID_RESPONSE, 502, AiFailureCategory.INVALID_RESPONSE);
    }

    @Test void onlyJwtIdentityOwnsUsageAndPrivateContextIsNotPersisted() throws Exception {
        var caller = user("identity-caller");
        user("identity-other");
        when(provider.extractEvents(any())).thenReturn(result(events(EventCategory.ACTIVITY)));
        assertThat(perform(token(caller.getId()), validRequest()).getResponse().getStatus()).isEqualTo(200);
        assertThat(usages.findAll()).singleElement().satisfies(usage -> {
            assertThat(usage.getServiceUserId()).isEqualTo(caller.getId());
            assertThat(AiUsageStatus.SUCCEEDED).isEqualTo(usage.getStatus());
        });
        assertThat(com.pettale.backend.usage.AiUsage.class.getDeclaredFields())
                .extracting(java.lang.reflect.Field::getName)
                .doesNotContain("transcript", "selectedPet", "knownPetNames", "prompt", "response");
    }

    @Test void invalidRequestIsRejectedBeforeReservation() throws Exception {
        var user = user("invalid-request");
        var response = perform(token(user.getId()), validRequest().replace("Oreo weighs 6.2kg", " ")).getResponse();
        assertThat(response.getStatus()).isEqualTo(400);
        assertThat(response.getContentAsString()).contains("INVALID_REQUEST");
        assertThat(usages.count()).isZero();
        verify(provider, never()).extractEvents(any());
    }

    @Test void acceptedTimeZonesArePassedToProviderContext() throws Exception {
        assertTimeZoneAccepted("Asia/Seoul");
        setup();
        assertTimeZoneAccepted("America/New_York");
    }

    @Test void invalidOrMissingTimeZoneIsRejectedBeforeReservation() throws Exception {
        var user = user("invalid-time-zone");
        var invalid = validRequest().replace("Asia/Seoul", "Mars/Olympus");
        assertThat(perform(token(user.getId()), invalid).getResponse().getStatus()).isEqualTo(400);
        assertThat(usages.count()).isZero();
        verify(provider, never()).extractEvents(any());

        setup();
        user = user("missing-time-zone");
        var missing = validRequest().replace(",\"timeZone\":\"Asia/Seoul\"", "");
        assertThat(perform(token(user.getId()), missing).getResponse().getStatus()).isEqualTo(400);
        assertThat(usages.count()).isZero();
        verify(provider, never()).extractEvents(any());
    }

    @Test void timeZoneIsTransientAndNotPersistedInUsage() {
        assertThat(com.pettale.backend.usage.AiUsage.class.getDeclaredFields())
                .extracting(java.lang.reflect.Field::getName)
                .doesNotContain("timeZone");
    }

    private void assertTimeZoneAccepted(String timeZone) throws Exception {
        var user = user("zone-" + timeZone);
        doAnswer(invocation -> {
            AiProvider.ExtractionInput input = invocation.getArgument(0);
            assertThat(input.timeZone()).isEqualTo(timeZone);
            return result(events(EventCategory.WEIGHT));
        }).when(provider).extractEvents(any());
        var request = validRequest().replace("Asia/Seoul", timeZone);
        assertThat(perform(token(user.getId()), request).getResponse().getStatus()).isEqualTo(200);
    }

    private void assertInvalid(ExtractedEventDraft event) throws Exception {
        assertInvalidResult(result(List.of(event)));
    }

    private void assertInvalidResult(AiProvider.ExtractionResult result) throws Exception {
        setup();
        var user = user("invalid-" + UUID.randomUUID());
        when(provider.extractEvents(any())).thenReturn(result);
        var response = perform(token(user.getId()), validRequest()).getResponse();
        assertThat(response.getStatus()).isEqualTo(502);
        assertThat(response.getContentAsString()).contains("INVALID_PROVIDER_RESPONSE").doesNotContain("Oreo weighs");
        assertThat(usages.findAll()).singleElement().satisfies(usage -> {
            assertThat(usage.getStatus()).isEqualTo(AiUsageStatus.FAILED);
            assertThat(usage.getFailureCategory()).isEqualTo(AiFailureCategory.INVALID_STRUCTURED_OUTPUT);
        });
    }

    private void assertFailure(ProviderFailure.Kind kind, int status, AiFailureCategory category) throws Exception {
        setup();
        var user = user("failure-" + kind);
        when(provider.extractEvents(any())).thenThrow(new ProviderFailure(kind));
        var response = perform(token(user.getId()), validRequest()).getResponse();
        assertThat(response.getStatus()).isEqualTo(status);
        assertThat(response.getContentAsString()).doesNotContain("OpenAI", "Oreo weighs", "stack");
        assertThat(usages.findAll()).singleElement().satisfies(usage -> {
            assertThat(usage.getStatus()).isEqualTo(AiUsageStatus.FAILED);
            assertThat(usage.getFailureCategory()).isEqualTo(category);
        });
    }

    private org.springframework.test.web.servlet.MvcResult perform(String token, String content) throws Exception {
        var request = MockMvcRequestBuilders.post("/api/v1/ai/extractions")
                .contentType("application/json").content(content);
        if (token != null) request.header("Authorization", "Bearer " + token);
        return mvc.perform(request).andReturn();
    }

    private List<ExtractedEventDraft> events(EventCategory... categories) {
        return Arrays.stream(categories).map(category -> new ExtractedEventDraft(
                category, category == EventCategory.WEIGHT ? "BODY_WEIGHT" : "EVENT_OBSERVED", NOW,
                category == EventCategory.WEIGHT ? 6.2 : null,
                category == EventCategory.WEIGHT ? "KG" : null, null, null, null)).toList();
    }

    private AiProvider.ExtractionResult result(List<ExtractedEventDraft> events) {
        return new AiProvider.ExtractionResult("OPENAI", "gpt-5-mini-2025-08-07", 100, 40, "resp_test", "1", events);
    }

    private String validRequest() {
        return """
                {"transcript":"Oreo weighs 6.2kg","recordedAt":"2026-08-16T12:00:00Z",
                 "selectedPet":{"clientPetId":"11111111-1111-1111-1111-111111111111","name":"Oreo"},
                 "knownPetNames":["Oreo","Creamy"],"spokenLanguage":"en-US","timeZone":"Asia/Seoul"}
                """;
    }

    private ServiceUser user(String subject) {
        return users.saveAndFlush(new ServiceUser(UUID.randomUUID(), subject, null, NOW));
    }

    private String token(UUID userId) {
        var issuedAt = Instant.now();
        var claims = JwtClaimsSet.builder().issuer("pettale-backend").subject(userId.toString())
                .issuedAt(issuedAt).expiresAt(issuedAt.plusSeconds(3600)).build();
        return jwtEncoder.encode(JwtEncoderParameters.from(
                JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
    }
}
