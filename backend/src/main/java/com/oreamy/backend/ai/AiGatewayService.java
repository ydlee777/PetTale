package com.oreamy.backend.ai;

import com.oreamy.backend.usage.AiFailureCategory;
import com.oreamy.backend.usage.AiOperation;
import com.oreamy.backend.usage.AiProviderMetadata;
import com.oreamy.backend.usage.AiQuotaExceeded;
import com.oreamy.backend.usage.AiUsage;
import com.oreamy.backend.usage.AiUsageService;
import java.util.UUID;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

@Service
public class AiGatewayService {
    private final AiUsageService usages;
    private final AiProvider provider;
    private final ExtractionValidator validator;

    public AiGatewayService(AiUsageService usages, AiProvider provider, ExtractionValidator validator) {
        this.usages = usages;
        this.provider = provider;
        this.validator = validator;
    }

    public AiUsage reserveEventExtraction(Authentication authentication) {
        return usages.reserve(authenticatedUserId(authentication), AiOperation.EVENT_EXTRACTION);
    }

    public ExtractionResponse extractEvents(Authentication authentication, ExtractionRequest request) {
        AiUsage usage;
        try {
            usage = usages.reserve(authenticatedUserId(authentication), AiOperation.EVENT_EXTRACTION);
        } catch (AiQuotaExceeded error) {
            throw new ExtractionFailure(ExtractionFailure.Code.QUOTA_EXCEEDED);
        }

        try {
            var result = provider.extractEvents(request.toProviderInput());
            var extraction = validator.validate(result.schemaVersion(), result.diaryText(), result.events());
            usages.succeed(usage.getId(), new AiProviderMetadata(
                    result.provider(), result.model(), result.inputTokens(), result.outputTokens(), result.providerRequestId()));
            return new ExtractionResponse(result.schemaVersion(), request.selectedPet().clientPetId(),
                    extraction.diaryText(), extraction.events());
        } catch (ProviderFailure error) {
            usages.fail(usage.getId(), failureCategory(error.kind()));
            throw new ExtractionFailure(apiCode(error.kind()));
        } catch (RuntimeException error) {
            usages.fail(usage.getId(), AiFailureCategory.PROVIDER_ERROR);
            throw new ExtractionFailure(ExtractionFailure.Code.PROVIDER_ERROR);
        }
    }

    public static UUID authenticatedUserId(Authentication authentication) {
        if (authentication == null || !authentication.isAuthenticated()) {
            throw new IllegalArgumentException("Authenticated Oreamy session is required");
        }
        return UUID.fromString(authentication.getName());
    }

    private static AiFailureCategory failureCategory(ProviderFailure.Kind kind) {
        return switch (kind) {
            case TIMEOUT -> AiFailureCategory.TIMEOUT;
            case RATE_LIMIT -> AiFailureCategory.RATE_LIMIT;
            case REFUSAL -> AiFailureCategory.REFUSAL;
            case INCOMPLETE -> AiFailureCategory.INCOMPLETE;
            case MISSING_OUTPUT -> AiFailureCategory.MISSING_OUTPUT;
            case INVALID_STRUCTURED_OUTPUT -> AiFailureCategory.INVALID_STRUCTURED_OUTPUT;
            case INVALID_RESPONSE -> AiFailureCategory.INVALID_RESPONSE;
            case ERROR -> AiFailureCategory.PROVIDER_ERROR;
        };
    }

    private static ExtractionFailure.Code apiCode(ProviderFailure.Kind kind) {
        return switch (kind) {
            case TIMEOUT -> ExtractionFailure.Code.PROVIDER_TIMEOUT;
            case RATE_LIMIT -> ExtractionFailure.Code.PROVIDER_RATE_LIMIT;
            case REFUSAL, INCOMPLETE, MISSING_OUTPUT, INVALID_STRUCTURED_OUTPUT, INVALID_RESPONSE ->
                    ExtractionFailure.Code.INVALID_PROVIDER_RESPONSE;
            case ERROR -> ExtractionFailure.Code.PROVIDER_ERROR;
        };
    }
}
