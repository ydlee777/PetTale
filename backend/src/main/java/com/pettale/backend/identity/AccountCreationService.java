package com.pettale.backend.identity;

import java.time.Instant;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Service
class AccountCreationService {
    private final ServiceUserRepository repository;

    AccountCreationService(ServiceUserRepository repository) { this.repository = repository; }

    @Transactional(propagation = Propagation.REQUIRES_NEW)
    ServiceUser create(String appleSubject, String email, Instant now) {
        return repository.saveAndFlush(new ServiceUser(UUID.randomUUID(), appleSubject, email, now));
    }
}
