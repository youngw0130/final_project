package com.creditn.domain.repository;

import com.creditn.domain.entity.Payment;
import com.creditn.domain.entity.enums.PaymentStatus;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface PaymentRepository extends JpaRepository<Payment, Long> {
    List<Payment> findByMoimIdOrderByApprovedAtDesc(Long moimId);
    List<Payment> findByMoimIdAndStatus(Long moimId, PaymentStatus status);
}
