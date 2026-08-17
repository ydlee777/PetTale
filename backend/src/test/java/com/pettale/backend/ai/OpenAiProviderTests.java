package com.pettale.backend.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.sun.net.httpserver.HttpServer;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.ObjectMapper;

class OpenAiProviderTests {
    private final ObjectMapper json = new ObjectMapper();
    private HttpServer server;

    @AfterEach void stopServer() {
        if (server != null) server.stop(0);
    }

    @Test void sendsCurrentResponsesStructuredOutputContractAndMapsUsage() throws Exception {
        var capturedAuthorization = new AtomicReference<String>();
        var capturedBody = new AtomicReference<String>();
        startServer(200, validResponse(), capturedAuthorization, capturedBody);
        var provider = provider();

        var result = provider.extractEvents(input());

        assertThat(capturedAuthorization).hasValue("Bearer test-server-key");
        var request = json.readTree(capturedBody.get());
        assertThat(request.path("model").asText()).isEqualTo("gpt-5-mini");
        assertThat(request.path("store").asBoolean()).isFalse();
        assertThat(request.path("reasoning").path("effort").asText()).isEqualTo("minimal");
        assertThat(request.path("text").path("verbosity").asText()).isEqualTo("low");
        assertThat(request.path("text").path("format").path("type").asText()).isEqualTo("json_schema");
        assertThat(request.path("text").path("format").path("name").asText()).isEqualTo("pettale_event_extraction_v2");
        assertThat(request.path("text").path("format").path("strict").asBoolean()).isTrue();
        assertThat(request.path("text").path("format").path("schema").path("additionalProperties").asBoolean()).isFalse();
        assertThat(request.path("instructions").asText())
                .contains("For every WEIGHT category event, eventType must be BODY_WEIGHT")
                .contains("category HEALTH and eventType VOMITING");
        assertThat(request.path("text").path("format").path("schema").path("properties")
                .path("events").path("items").path("properties").path("eventType").path("description").asText())
                .contains("WEIGHT", "BODY_WEIGHT", "HEALTH", "VOMITING");
        assertThat(request.path("input").asText()).contains("Oreo weighs 6.2kg", "Oreo", "Creamy")
                .contains("\"timeZone\":\"Asia/Seoul\"")
                .doesNotContain("client-pet-id");
        assertThat(request.path("instructions").asText())
                .contains("using only the supplied timeZone")
                .contains("absolute ISO-8601 UTC instant");
        assertThat(result.provider()).isEqualTo("OPENAI");
        assertThat(result.model()).isEqualTo("gpt-5-mini-2025-08-07");
        assertThat(result.inputTokens()).isEqualTo(123);
        assertThat(result.outputTokens()).isEqualTo(45);
        assertThat(result.providerRequestId()).isEqualTo("resp_contract_test");
        assertThat(result.diaryText()).isEqualTo("Oreo weighs 6.2 kg today.");
        assertThat(result.events()).singleElement().satisfies(event -> {
            assertThat(event.category()).isEqualTo(EventCategory.WEIGHT);
            assertThat(event.eventType()).isEqualTo("BODY_WEIGHT");
            assertThat(event.numericValue()).isEqualTo(6.2);
            assertThat(event.unit()).isEqualTo("KG");
        });
    }

    @Test void omitsOptionalOptimizationControlsByDefault() throws Exception {
        var capturedBody = new AtomicReference<String>();
        startServer(200, validResponse(), new AtomicReference<>(), capturedBody);
        var provider = new OpenAiProvider(json, "test-server-key", "gpt-5-mini", "", "",
                "http://127.0.0.1:" + server.getAddress().getPort(), Duration.ofSeconds(2));

        provider.extractEvents(input());

        var request = json.readTree(capturedBody.get());
        assertThat(request.has("reasoning")).isFalse();
        assertThat(request.path("text").has("verbosity")).isFalse();
    }

    @Test void findsOutputTextAcrossMultipleTypedOutputAndContentItems() throws Exception {
        var root = json.readTree(validResponse()).deepCopy();
        var output = (tools.jackson.databind.node.ArrayNode) root.path("output");
        output.insertObject(0).put("type", "reasoning").put("id", "rs_test");
        ((tools.jackson.databind.node.ArrayNode) output.get(1).path("content"))
                .insertObject(0).put("type", "annotation");
        startServer(200, json.writeValueAsString(root), new AtomicReference<>(), new AtomicReference<>());

        assertThat(provider().extractEvents(input()).events()).hasSize(1);
    }

    @Test void mapsRefusal() throws Exception {
        startServer(200, responseWith("completed", "refusal", "cannot comply", null),
                new AtomicReference<>(), new AtomicReference<>());
        assertKind(ProviderFailure.Kind.REFUSAL);
    }

    @Test void mapsIncompleteResponse() throws Exception {
        startServer(200, responseWith("incomplete", null, null, "max_output_tokens"),
                new AtomicReference<>(), new AtomicReference<>());
        assertKind(ProviderFailure.Kind.INCOMPLETE);
    }

    @Test void rejectsCompletedResponseWithoutOutputText() throws Exception {
        startServer(200, responseWith("completed", "annotation", null, null),
                new AtomicReference<>(), new AtomicReference<>());
        assertKind(ProviderFailure.Kind.MISSING_OUTPUT);
    }

    @Test void rejectsInvalidStructuredJson() throws Exception {
        startServer(200, responseWith("completed", "output_text", "not-json", null),
                new AtomicReference<>(), new AtomicReference<>());
        assertKind(ProviderFailure.Kind.INVALID_STRUCTURED_OUTPUT);
    }

    @Test void ignoresUnknownContentTypeWhenValidOutputTextExists() throws Exception {
        var root = json.readTree(validResponse()).deepCopy();
        var output = (tools.jackson.databind.node.ArrayNode) root.path("output").get(0).path("content");
        output.insertObject(0).put("type", "future_content_type");
        startServer(200, json.writeValueAsString(root), new AtomicReference<>(), new AtomicReference<>());

        assertThat(provider().extractEvents(input()).events()).hasSize(1);
    }

    @Test void rejectsUnknownCategoryFromRawProviderResponse() throws Exception {
        startServer(200, validResponse().replace("WEIGHT", "DIAGNOSIS"), new AtomicReference<>(), new AtomicReference<>());

        assertThatThrownBy(() -> provider().extractEvents(input()))
                .isInstanceOf(ProviderFailure.class)
                .satisfies(error -> assertThat(((ProviderFailure) error).kind())
                        .isEqualTo(ProviderFailure.Kind.INVALID_STRUCTURED_OUTPUT));
    }

    @Test void mapsProviderRateLimitWithoutReturningProviderBody() throws Exception {
        startServer(429, "sensitive provider error body", new AtomicReference<>(), new AtomicReference<>());

        assertThatThrownBy(() -> provider().extractEvents(input()))
                .isInstanceOf(ProviderFailure.class)
                .satisfies(error -> {
                    assertThat(((ProviderFailure) error).kind()).isEqualTo(ProviderFailure.Kind.RATE_LIMIT);
                    assertThat(error.getMessage()).doesNotContain("sensitive");
                });
    }

    @Test void mapsProviderTimeout() throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/responses", exchange -> {
            try { Thread.sleep(250); } catch (InterruptedException error) { Thread.currentThread().interrupt(); }
            exchange.close();
        });
        server.start();
        var slowProvider = new OpenAiProvider(json, "test-server-key", "gpt-5-mini", "minimal", "low",
                "http://127.0.0.1:" + server.getAddress().getPort(), Duration.ofMillis(50));
        assertThatThrownBy(() -> slowProvider.extractEvents(input()))
                .isInstanceOf(ProviderFailure.class)
                .satisfies(error -> assertThat(((ProviderFailure) error).kind()).isEqualTo(ProviderFailure.Kind.TIMEOUT));
    }

    private OpenAiProvider provider() {
        return new OpenAiProvider(json, "test-server-key", "gpt-5-mini", "minimal", "low",
                "http://127.0.0.1:" + server.getAddress().getPort(), Duration.ofSeconds(2));
    }

    private AiProvider.ExtractionInput input() {
        return new AiProvider.ExtractionInput(
                "Oreo weighs 6.2kg", Instant.parse("2026-08-16T12:00:00Z"),
                "Oreo", List.of("Oreo", "Creamy"), "en-US", "Asia/Seoul");
    }

    private void assertKind(ProviderFailure.Kind kind) {
        assertThatThrownBy(() -> provider().extractEvents(input()))
                .isInstanceOf(ProviderFailure.class)
                .satisfies(error -> assertThat(((ProviderFailure) error).kind()).isEqualTo(kind));
    }

    private void startServer(int status, String response, AtomicReference<String> authorization,
            AtomicReference<String> body) throws Exception {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext("/v1/responses", exchange -> {
            authorization.set(exchange.getRequestHeaders().getFirst("Authorization"));
            body.set(new String(exchange.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            var bytes = response.getBytes(StandardCharsets.UTF_8);
            exchange.sendResponseHeaders(status, bytes.length);
            exchange.getResponseBody().write(bytes);
            exchange.close();
        });
        server.start();
    }

    private String validResponse() throws Exception {
        var output = """
                {"schemaVersion":"2","diaryText":"Oreo weighs 6.2 kg today.","events":[{"category":"WEIGHT","eventType":" body_weight ",
                "occurredAt":"2026-08-16T12:00:00Z","numericValue":6.2,"unit":"kg",
                "count":null,"durationMinutes":null,"description":null}]}
                """;
        var root = json.createObjectNode();
        root.put("id", "resp_contract_test");
        root.put("status", "completed");
        root.put("model", "gpt-5-mini-2025-08-07");
        var message = root.putArray("output").addObject();
        message.put("type", "message");
        message.put("role", "assistant");
        message.put("status", "completed");
        var content = message.putArray("content").addObject();
        content.put("type", "output_text");
        content.put("text", output);
        root.putObject("usage").put("input_tokens", 123).put("output_tokens", 45);
        return json.writeValueAsString(root);
    }

    private String responseWith(String status, String contentType, String text, String incompleteReason)
            throws Exception {
        var root = json.createObjectNode();
        root.put("id", "resp_state_test");
        root.put("status", status);
        root.put("model", "gpt-5-mini-2025-08-07");
        if (incompleteReason != null) root.putObject("incomplete_details").put("reason", incompleteReason);
        var message = root.putArray("output").addObject();
        message.put("type", "message");
        var content = message.putArray("content");
        if (contentType != null) {
            var item = content.addObject().put("type", contentType);
            if (text != null) item.put("text", text);
        }
        root.putObject("usage").put("input_tokens", 10).put("output_tokens", 5);
        return json.writeValueAsString(root);
    }
}
