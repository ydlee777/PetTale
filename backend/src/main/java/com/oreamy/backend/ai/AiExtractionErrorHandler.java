package com.oreamy.backend.ai;

import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

@RestControllerAdvice(assignableTypes = AiExtractionController.class)
final class AiExtractionErrorHandler {
    @ExceptionHandler(ExtractionFailure.class)
    ResponseEntity<Map<String, String>> extractionFailure(ExtractionFailure failure) {
        var status = switch (failure.code()) {
            case QUOTA_EXCEEDED -> HttpStatus.TOO_MANY_REQUESTS;
            case PROVIDER_TIMEOUT -> HttpStatus.GATEWAY_TIMEOUT;
            case PROVIDER_RATE_LIMIT -> HttpStatus.SERVICE_UNAVAILABLE;
            case PROVIDER_ERROR, INVALID_PROVIDER_RESPONSE -> HttpStatus.BAD_GATEWAY;
        };
        return ResponseEntity.status(status).body(Map.of(
                "code", failure.code().name(),
                "message", "Event extraction is temporarily unavailable."));
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    ResponseEntity<Map<String, String>> invalidRequest() {
        return ResponseEntity.badRequest().body(Map.of(
                "code", "INVALID_REQUEST",
                "message", "The extraction request is invalid."));
    }
}
