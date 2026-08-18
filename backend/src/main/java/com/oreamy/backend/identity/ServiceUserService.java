package com.oreamy.backend.identity;

import java.time.Clock;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ServiceUserService {
    private final ServiceUserRepository repository;
    private final AccountCreationService creationService;
    private final Clock clock;

    public ServiceUserService(ServiceUserRepository repository, AccountCreationService creationService, Clock clock) {
        this.repository = repository;
        this.creationService = creationService;
        this.clock = clock;
    }

    public ServiceUser resolve(String appleSubject, String verifiedEmail) {
        var existing = repository.findByAppleSubject(appleSubject);
        if (existing.isPresent()) {
            return captureEmail(existing.get(), verifiedEmail);
        }
        try {
            return creationService.create(appleSubject, verifiedEmail, clock.instant());
        } catch (DataIntegrityViolationException race) {
            return repository.findByAppleSubject(appleSubject).orElseThrow(() -> race);
        }
    }

    @Transactional
    ServiceUser captureEmail(ServiceUser user, String email) {
        user.captureVerifiedEmailIfMissing(email, clock.instant());
        return user;
    }
}
