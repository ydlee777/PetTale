package com.oreamy.backend.subscription;

import com.apple.itunes.storekit.model.Environment;
import com.apple.itunes.storekit.verification.SignedDataVerifier;
import java.io.InputStream;
import java.util.Set;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;

@Configuration
public class AppleVerificationConfiguration {
    @Bean("productionAppleVerifier")
    SignedDataVerifier productionAppleVerifier(
            @Value("${oreamy.app-store.bundle-id}") String bundleId,
            @Value("${oreamy.app-store.app-apple-id}") long appAppleId,
            @Value("${oreamy.app-store.enable-online-certificate-checks:true}") boolean onlineChecks,
            @Value("classpath:apple/AppleRootCA-G2.pem") Resource rootG2,
            @Value("classpath:apple/AppleRootCA-G3.pem") Resource rootG3) throws Exception {
        return new SignedDataVerifier(streams(rootG2, rootG3), bundleId, appAppleId,
                Environment.PRODUCTION, onlineChecks);
    }

    @Bean("sandboxAppleVerifier")
    SignedDataVerifier sandboxAppleVerifier(
            @Value("${oreamy.app-store.bundle-id}") String bundleId,
            @Value("${oreamy.app-store.enable-online-certificate-checks:true}") boolean onlineChecks,
            @Value("classpath:apple/AppleRootCA-G2.pem") Resource rootG2,
            @Value("classpath:apple/AppleRootCA-G3.pem") Resource rootG3) throws Exception {
        return new SignedDataVerifier(streams(rootG2, rootG3), bundleId, null,
                Environment.SANDBOX, onlineChecks);
    }

    private Set<InputStream> streams(Resource first, Resource second) throws Exception {
        return Set.of(first.getInputStream(), second.getInputStream());
    }
}
