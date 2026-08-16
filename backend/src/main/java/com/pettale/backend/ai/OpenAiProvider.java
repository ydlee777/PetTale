package com.pettale.backend.ai;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.node.ArrayNode;
import tools.jackson.databind.node.ObjectNode;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpTimeoutException;
import java.time.Duration;
import java.util.List;
import java.util.LinkedHashSet;
import java.util.Locale;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
final class OpenAiProvider implements AiProvider {
    private static final Logger log = LoggerFactory.getLogger(OpenAiProvider.class);
    static final String PROMPT_VERSION = "pettale-event-extraction-v1";
    private static final String INSTRUCTIONS = """
            You extract pet-life event drafts from one user-approved transcript. Prompt version: pettale-event-extraction-v1.
            Use only facts supported by the transcript and supplied pet-name context. Pet names help interpret speech-recognition errors; never rewrite the transcript.
            Never invent measurements, counts, durations, medications, or diagnoses. Preserve observations without converting them into diagnoses.
            Return every supported event in one response. Prefer concise uppercase eventType and unit codes. Put structured values in their fields.
            For every WEIGHT category event, eventType must be BODY_WEIGHT. WEIGHT is a category and must never be used as an eventType.
            When the transcript explicitly describes the pet vomiting, use category HEALTH and eventType VOMITING. Never use VOMITED or VOMIT for that observation.
            Interpret relative and local temporal expressions using only the supplied timeZone; never infer time zone from language or other context.
            Return occurredAt as an absolute ISO-8601 UTC instant. If no more precise event time is stated, use recordedAt. Do not invent temporal precision. Follow the supplied JSON schema exactly.
            """;

    private final ObjectMapper json;
    private final HttpClient http;
    private final String apiKey;
    private final String model;
    private final URI endpoint;
    private final Duration timeout;

    OpenAiProvider(ObjectMapper json,
            @Value("${pettale.ai.openai-api-key}") String apiKey,
            @Value("${pettale.ai.extraction-model}") String model,
            @Value("${pettale.ai.openai-base-url}") String baseUrl,
            @Value("${pettale.ai.provider-timeout}") Duration timeout) {
        this.json = json;
        this.apiKey = apiKey;
        this.model = model;
        this.endpoint = URI.create(baseUrl).resolve("/v1/responses");
        this.timeout = timeout;
        this.http = HttpClient.newBuilder().connectTimeout(timeout).build();
    }

    @Override
    public ExtractionResult extractEvents(ExtractionInput input) {
        if (apiKey == null || apiKey.isBlank()) throw new ProviderFailure(ProviderFailure.Kind.ERROR);
        try {
            var request = HttpRequest.newBuilder(endpoint)
                    .timeout(timeout)
                    .header("Authorization", "Bearer " + apiKey)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(requestBody(input))))
                    .build();
            var response = http.send(request, HttpResponse.BodyHandlers.ofString());
            if (response.statusCode() == 429) throw new ProviderFailure(ProviderFailure.Kind.RATE_LIMIT);
            if (response.statusCode() < 200 || response.statusCode() >= 300) {
                throw new ProviderFailure(ProviderFailure.Kind.ERROR);
            }
            return parse(response.body(), response.statusCode(),
                    response.headers().firstValue("x-request-id").orElse(null));
        } catch (HttpTimeoutException error) {
            throw new ProviderFailure(ProviderFailure.Kind.TIMEOUT, error);
        } catch (InterruptedException error) {
            Thread.currentThread().interrupt();
            throw new ProviderFailure(ProviderFailure.Kind.ERROR, error);
        } catch (ProviderFailure error) {
            throw error;
        } catch (IOException | RuntimeException error) {
            throw new ProviderFailure(ProviderFailure.Kind.INVALID_RESPONSE, error);
        }
    }

    private ObjectNode requestBody(ExtractionInput input) {
        var body = json.createObjectNode();
        body.put("model", model);
        body.put("store", false);
        body.put("instructions", INSTRUCTIONS);
        body.put("input", inputText(input));
        body.put("max_output_tokens", 2_000);
        var format = body.putObject("text").putObject("format");
        format.put("type", "json_schema");
        format.put("name", "pettale_event_extraction_v1");
        format.put("strict", true);
        format.set("schema", schema());
        return body;
    }

    private String inputText(ExtractionInput input) {
        var value = json.createObjectNode();
        value.put("transcript", input.transcript());
        value.put("recordedAt", input.recordedAt().toString());
        value.put("selectedPetName", input.selectedPetName());
        var names = value.putArray("knownPetNames");
        input.knownPetNames().forEach(names::add);
        if (input.spokenLanguage() == null) value.putNull("spokenLanguage");
        else value.put("spokenLanguage", input.spokenLanguage());
        value.put("timeZone", input.timeZone());
        return json.writeValueAsString(value);
    }

    private ObjectNode schema() {
        var root = objectSchema("schemaVersion", "events");
        root.withObject("properties").set("schemaVersion", json.createObjectNode().put("type", "string").put("const", "1"));
        var events = json.createObjectNode().put("type", "array").put("minItems", 1).put("maxItems", 20);
        var event = objectSchema("category", "eventType", "occurredAt", "numericValue", "unit", "count", "durationMinutes", "description");
        var properties = event.withObject("properties");
        var categories = json.createArrayNode();
        for (var category : EventCategory.values()) categories.add(category.name());
        properties.set("category", json.createObjectNode().put("type", "string").set("enum", categories));
        properties.set("eventType", nullableString()
                .put("description", "Canonical uppercase event code. For category WEIGHT this must be BODY_WEIGHT. An explicit pet vomiting observation must use HEALTH with VOMITING, never VOMITED or VOMIT."));
        properties.set("occurredAt", json.createObjectNode().put("type", "string"));
        properties.set("numericValue", nullableNumber());
        properties.set("unit", nullableString());
        properties.set("count", nullableInteger());
        properties.set("durationMinutes", nullableInteger());
        properties.set("description", nullableString());
        events.set("items", event);
        root.withObject("properties").set("events", events);
        return root;
    }

    private ObjectNode objectSchema(String... required) {
        var object = json.createObjectNode().put("type", "object").put("additionalProperties", false);
        object.set("properties", json.createObjectNode());
        var fields = object.putArray("required");
        for (var field : required) fields.add(field);
        return object;
    }

    private ObjectNode nullableString() { return nullable("string"); }
    private ObjectNode nullableNumber() { return nullable("number"); }
    private ObjectNode nullableInteger() { return nullable("integer"); }
    private ObjectNode nullable(String type) {
        ArrayNode types = json.createArrayNode().add(type).add("null");
        return json.createObjectNode().set("type", types);
    }

    private ExtractionResult parse(String body, int httpStatus, String requestId) {
        final JsonNode root;
        try {
            root = json.readTree(body);
        } catch (RuntimeException error) {
            log.warn("OpenAI response rejected httpStatus={} requestId={} category=INVALID_ENVELOPE",
                    httpStatus, requestId);
            throw new ProviderFailure(ProviderFailure.Kind.INVALID_RESPONSE, error);
        }
        var status = root.path("status").asText(null);
        var responseId = root.path("id").asText(null);
        var responseModel = root.path("model").asText(null);
        var outputTypes = new LinkedHashSet<String>();
        var contentTypes = new LinkedHashSet<String>();
        boolean refusal = false;
        boolean outputTextPresent = false;
        String outputText = null;
        for (var output : root.path("output")) {
            outputTypes.add(output.path("type").asText("missing"));
            for (var content : output.path("content")) {
                var type = content.path("type").asText("missing");
                contentTypes.add(type);
                if ("refusal".equals(type)) refusal = true;
                if ("output_text".equals(type) && !outputTextPresent) {
                    outputText = content.path("text").asText(null);
                    outputTextPresent = outputText != null;
                }
            }
        }
        var usage = root.path("usage");
        var usagePresent = usage.isObject();
        var inputTokens = usage.path("input_tokens").canConvertToLong()
                ? usage.path("input_tokens").asLong() : null;
        var outputTokens = usage.path("output_tokens").canConvertToLong()
                ? usage.path("output_tokens").asLong() : null;
        var incompleteReason = root.path("incomplete_details").path("reason").asText(null);

        if (refusal) {
            diagnostic(httpStatus, requestId, responseId, responseModel, status, outputTypes, contentTypes,
                    outputTextPresent, incompleteReason, true, usagePresent, inputTokens, outputTokens, "REFUSAL");
            throw new ProviderFailure(ProviderFailure.Kind.REFUSAL);
        }
        if ("incomplete".equals(status)) {
            diagnostic(httpStatus, requestId, responseId, responseModel, status, outputTypes, contentTypes,
                    outputTextPresent, incompleteReason, false, usagePresent, inputTokens, outputTokens, "INCOMPLETE");
            throw new ProviderFailure(ProviderFailure.Kind.INCOMPLETE);
        }
        if (!"completed".equals(status)) {
            diagnostic(httpStatus, requestId, responseId, responseModel, status, outputTypes, contentTypes,
                    outputTextPresent, incompleteReason, false, usagePresent, inputTokens, outputTokens, "INVALID_STATUS");
            throw new ProviderFailure(ProviderFailure.Kind.INVALID_RESPONSE);
        }
        if (!outputTextPresent) {
            diagnostic(httpStatus, requestId, responseId, responseModel, status, outputTypes, contentTypes,
                    false, incompleteReason, false, usagePresent, inputTokens, outputTokens, "MISSING_OUTPUT");
            throw new ProviderFailure(ProviderFailure.Kind.MISSING_OUTPUT);
        }
        final StructuredResponse structured;
        try {
            structured = json.readValue(outputText, StructuredResponse.class);
        } catch (RuntimeException error) {
            diagnostic(httpStatus, requestId, responseId, responseModel, status, outputTypes, contentTypes,
                    true, incompleteReason, false, usagePresent, inputTokens, outputTokens,
                    "INVALID_STRUCTURED_OUTPUT");
            throw new ProviderFailure(ProviderFailure.Kind.INVALID_STRUCTURED_OUTPUT, error);
        }
        return new ExtractionResult(
                "OPENAI",
                requiredText(root, "model"), requiredLong(usage, "input_tokens"),
                requiredLong(usage, "output_tokens"), requiredText(root, "id"),
                structured.schemaVersion(),
                canonicalEvents(structured.events()));
    }

    private static List<ExtractedEventDraft> canonicalEvents(List<ExtractedEventDraft> events) {
        if (events == null) return null;
        return events.stream().map(event -> event == null ? null : new ExtractedEventDraft(
                event.category(), canonicalCode(event.eventType()), event.occurredAt(), event.numericValue(),
                canonicalCode(event.unit()), event.count(), event.durationMinutes(), event.description())).toList();
    }

    private static String canonicalCode(String value) {
        if (value == null) return null;
        var normalized = value.trim().toUpperCase(Locale.ROOT);
        return normalized.isEmpty() ? null : normalized;
    }

    private static void diagnostic(int httpStatus, String requestId, String responseId, String model,
            String status, LinkedHashSet<String> outputTypes, LinkedHashSet<String> contentTypes,
            boolean outputTextPresent, String incompleteReason, boolean refusal, boolean usagePresent,
            Long inputTokens, Long outputTokens, String category) {
        log.warn("OpenAI response rejected httpStatus={} requestId={} responseId={} model={} status={} "
                        + "outputTypes={} contentTypes={} outputTextPresent={} incompleteReason={} refusal={} "
                        + "usagePresent={} inputTokens={} outputTokens={} category={}",
                httpStatus, requestId, responseId, model, status, outputTypes, contentTypes,
                outputTextPresent, incompleteReason, refusal, usagePresent, inputTokens, outputTokens, category);
    }

    private static String requiredText(JsonNode node, String field) {
        var value = node.path(field).asText(null);
        if (value == null || value.isBlank()) invalid();
        return value;
    }

    private static long requiredLong(JsonNode node, String field) {
        if (!node.path(field).canConvertToLong()) invalid();
        return node.path(field).asLong();
    }

    private static void invalid() { throw new ProviderFailure(ProviderFailure.Kind.INVALID_RESPONSE); }
    private record StructuredResponse(String schemaVersion, List<ExtractedEventDraft> events) {}
}
