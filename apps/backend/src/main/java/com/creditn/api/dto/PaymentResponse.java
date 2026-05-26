package com.creditn.api.dto;

import com.creditn.domain.entity.Payment;
import com.creditn.domain.entity.enums.PaymentStatus;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record PaymentResponse(
        Long id,
        Long moimId,
        String merchantName,
        String category,
        BigDecimal amount,
        LocalDateTime approvedAt,
        PaymentStatus status
) {
    public static PaymentResponse from(Payment p) {
        return new PaymentResponse(
                p.getId(),
                p.getMoim().getId(),
                p.getMerchantName(),
                p.getCategory(),
                p.getAmount(),
                p.getApprovedAt(),
                p.getStatus()
        );
    }
}
