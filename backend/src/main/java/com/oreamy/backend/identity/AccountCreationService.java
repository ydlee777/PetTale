package com.oreamy.backend.identity;

import java.time.Duration;
import java.time.Instant;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
class AccountCreationService {
    private final ServiceUserRepository repository;
    private final Duration trialDuration;

    AccountCreationService(
            ServiceUserRepository repository,
            @Value("${oreamy.trial.duration}") Duration trialDuration) {
        if (trialDuration.isNegative() || trialDuration.isZero()) {
            throw new IllegalArgumentException("Trial duration must be positive");
        }
        this.repository = repository;
        this.trialDuration = trialDuration;
    }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    ServiceUser create(String appleSubject, String email, Instant now) {
        var user = new ServiceUser(UUID.randomUUID(), appleSubject, email, now);
        user.activateTrialIfEligible(now, trialDuration);
        return repository.saveAndFlush(user);
    }
}
