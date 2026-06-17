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

    @Query("SELECT p FROM Participant p JOIN FETCH p.user JOIN FETCH p.moim WHERE p.user.id = :userId AND p.moim.id = :moimId")
    Optional<Participant> findByUserIdAndMoimId(@Param("userId") Long userId, @Param("moimId") Long moimId);

    @Query("SELECT p FROM Participant p JOIN FETCH p.user WHERE p.moim.id = :moimId AND p.depositStatus = :status")
    List<Participant> findByMoimIdAndDepositStatus(@Param("moimId") Long moimId, @Param("status") DepositStatus status);

    boolean existsByUserIdAndMoimId(Long userId, Long moimId);

    @Query("SELECT p FROM Participant p JOIN FETCH p.user JOIN FETCH p.moim WHERE p.depositStatus = :status AND p.depositDeadline < :deadline")
    List<Participant> findByDepositStatusAndDepositDeadlineBefore(@Param("status") DepositStatus status, @Param("deadline") LocalDateTime deadline);
}
