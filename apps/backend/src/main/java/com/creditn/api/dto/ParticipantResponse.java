package com.creditn.api.dto;

import com.creditn.domain.entity.Participant;
import com.creditn.domain.entity.enums.DepositStatus;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record ParticipantResponse(
        Long id,
        Long userId,
        String username,
        BigDecimal depositAmount,
        DepositStatus depositStatus,
        LocalDateTime depositedAt,
        LocalDateTime depositDeadline,
        BigDecimal shareAmount,
        BigDecimal refundAmount
) {
    public static ParticipantResponse from(Participant p) {
        return new ParticipantResponse(
                p.getId(),
                p.getUser().getId(),
                p.getUser().getUsername(),
                p.getDepositAmount(),
                p.getDepositStatus(),
                p.getDepositedAt(),
                p.getDepositDeadline(),
                p.getShareAmount(),
                p.getRefundAmount()
        );
    }
}
