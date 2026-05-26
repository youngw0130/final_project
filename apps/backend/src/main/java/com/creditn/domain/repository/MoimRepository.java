package com.creditn.domain.repository;

import com.creditn.domain.entity.Moim;
import com.creditn.domain.entity.enums.MoimStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface MoimRepository extends JpaRepository<Moim, Long> {
    Optional<Moim> findByInviteCode(String inviteCode);
    List<Moim> findByCreatorId(Long creatorId);
    List<Moim> findByStatus(MoimStatus status);
}
