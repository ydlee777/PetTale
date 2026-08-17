package com.pettale.backend.access;

import com.pettale.backend.ai.AiGatewayService;
import com.pettale.backend.usage.AiUsageService;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/service-access")
final class ServiceAccessController {
    private final AiUsageService usages;

    ServiceAccessController(AiUsageService usages) {
        this.usages = usages;
    }

    @GetMapping
    ServiceAccessResponse get(Authentication authentication) {
        var snapshot = usages.serviceAccess(AiGatewayService.authenticatedUserId(authentication));
        return new ServiceAccessResponse(
                snapshot.access().plan(),
                snapshot.access().trialStartedAt(),
                snapshot.access().trialExpiresAt(),
                snapshot.access().trialEligible(),
                snapshot.access().monthlyAiLimit(),
                snapshot.used(),
                snapshot.remaining());
    }
}
