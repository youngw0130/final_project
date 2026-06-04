package com.creditn.domain.repository;

import com.creditn.domain.entity.Moim;
import com.creditn.domain.entity.enums.MoimStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface MoimRepository extends JpaRepository<Moim, Long> {
    Optional<Moim> findByInviteCode(String inviteCode);
    List<Moim> findByCreatorId(Long creatorId);
    List<Moim> findByStatus(MoimStatus status);

    @Query("SELECT DISTINCT m FROM Moim m JOIN FETCH m.participants p JOIN FETCH p.user WHERE p.user.id = :userId")
    List<Moim> findMoimsByUserId(@Param("userId") Long userId);
}
