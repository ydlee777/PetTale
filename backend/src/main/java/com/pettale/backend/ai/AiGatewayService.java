package com.pettale.backend.ai;

import com.pettale.backend.usage.AiOperation;
import com.pettale.backend.usage.AiUsage;
import com.pettale.backend.usage.AiUsageService;
import java.util.UUID;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

@Service
public class AiGatewayService {
    private final AiUsageService usages;

    public AiGatewayService(AiUsageService usages) { this.usages = usages; }

    public AiUsage reserveEventExtraction(Authentication authentication) {
        return usages.reserve(authenticatedUserId(authentication), AiOperation.EVENT_EXTRACTION);
    }

    static UUID authenticatedUserId(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new IllegalArgumentException("Authenticated Pettale session is required");
        }
        return UUID.fromString(authentication.getName());
    }
}
