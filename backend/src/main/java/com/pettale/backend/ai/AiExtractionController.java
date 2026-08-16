package com.pettale.backend.ai;

import jakarta.validation.Valid;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/ai/extractions")
final class AiExtractionController {
    private final AiGatewayService gateway;

    AiExtractionController(AiGatewayService gateway) { this.gateway = gateway; }

    @PostMapping
    ExtractionResponse extract(Authentication authentication, @Valid @RequestBody ExtractionRequest request) {
        return gateway.extractEvents(authentication, request);
    }
}
