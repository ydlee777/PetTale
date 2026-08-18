package com.oreamy.backend.subscription;

import com.apple.itunes.storekit.model.Environment;
import com.apple.itunes.storekit.model.JWSTransactionDecodedPayload;
import com.apple.itunes.storekit.verification.SignedDataVerifier;
import com.apple.itunes.storekit.verification.VerificationException;
import java.time.Instant;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.stereotype.Component;

@Component
public class OfficialAppleTransactionVerifier implements AppleTransactionVerifier {
    private final SignedDataVerifier production;
    private final SignedDataVerifier sandbox;

    public OfficialAppleTransactionVerifier(
            @Qualifier("productionAppleVerifier") SignedDataVerifier production,
            @Qualifier("sandboxAppleVerifier") SignedDataVerifier sandbox) {
        this.production = production;
        this.sandbox = sandbox;
    }

    @Override
    public VerifiedAppleTransaction verify(String signedTransaction) {
        try {
            return map(production.verifyAndDecodeTransaction(signedTransaction));
        } catch (VerificationException productionFailure) {
            try {
                return map(sandbox.verifyAndDecodeTransaction(signedTransaction));
            } catch (VerificationException sandboxFailure) {
                throw new EntitlementFailure("invalid_apple_transaction");
            }
        }
    }

    private VerifiedAppleTransaction map(JWSTransactionDecodedPayload payload) {
        AppleEnvironment environment = payload.getEnvironment() == Environment.PRODUCTION
                ? AppleEnvironment.PRODUCTION : AppleEnvironment.SANDBOX;
        return new VerifiedAppleTransaction(
                payload.getProductId(), payload.getOriginalTransactionId(), payload.getTransactionId(),
                payload.getAppAccountToken(), environment, instant(payload.getExpiresDate()),
                instant(payload.getRevocationDate()), payload.getRawRevocationReason() == null
                        ? null : payload.getRawRevocationReason().toString(), instant(payload.getSignedDate()));
    }

    private Instant instant(Long epochMilliseconds) {
        return epochMilliseconds == null ? null : Instant.ofEpochMilli(epochMilliseconds);
    }
}
