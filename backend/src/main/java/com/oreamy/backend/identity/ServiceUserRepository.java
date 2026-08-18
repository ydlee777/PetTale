package com.oreamy.backend.identity;

import java.util.Optional;
import java.util.UUID;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ServiceUserRepository extends JpaRepository<ServiceUser, UUID> {
    Optional<ServiceUser> findByAppleSubject(String appleSubject);

    @Lock(LockModeType.PESSIMISTIC_WRITE)
    @Query("select user from ServiceUser user where user.id = :id")
    Optional<ServiceUser> findByIdForUpdate(@Param("id") UUID id);
}
