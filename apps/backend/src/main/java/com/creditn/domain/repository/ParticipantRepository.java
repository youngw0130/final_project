package com.creditn.domain.repository;

import com.creditn.domain.entity.Participant;
import com.creditn.domain.entity.enums.DepositStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface ParticipantRepository extends JpaRepository<Participant, Long> {
    @Query("SELECT p FROM Participant p JOIN FETCH p.user WHERE p.moim.id = :moimId")
    List<Participant> findByMoimId(@Param("moimId") Long moimId);
    List<Participant> findByUserId(Long userId);
    Optional<Participant> findByUserIdAndMoimId(Long userId, Long moimId);
    List<Participant> findByMoimIdAndDepositStatus(Long moimId, DepositStatus status);
    boolean existsByUserIdAndMoimId(Long userId, Long moimId);
    List<Participant> findByDepositStatusAndDepositDeadlineBefore(DepositStatus status, LocalDateTime deadline);
}
