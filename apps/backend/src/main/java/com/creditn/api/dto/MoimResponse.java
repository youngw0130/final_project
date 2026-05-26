package com.creditn.api.dto;

import com.creditn.domain.entity.Moim;
import com.creditn.domain.entity.enums.MoimStatus;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record MoimResponse(
        Long id,
        Long creatorId,
        String title,
        String description,
        String emoji,
        LocalDateTime scheduledAt,
        String inviteCode,
        String virtualAccountNumber,
        String virtualAccountBank,
        BigDecimal depositPerPerson,
        BigDecimal targetAmount,
        BigDecimal totalDeposited,
        BigDecimal totalSpent,
        BigDecimal balance,
        BigDecimal depositRate,
        MoimStatus status,
        Integer targetParticipantCount,
        int currentParticipantCount
) {
    public static MoimResponse from(Moim m) {
        return new MoimResponse(
                m.getId(),
                m.getCreator().getId(),
                m.getTitle(),
                m.getDescription(),
                m.getEmoji(),
                m.getScheduledAt(),
                m.getInviteCode(),
                m.getVirtualAccountNumber(),
                m.getVirtualAccountBank(),
                m.getDepositPerPerson(),
                m.getTargetAmount(),
                m.getTotalDeposited(),
                m.getTotalSpent(),
                m.getBalance(),
                m.getDepositRate(),
                m.getStatus(),
                m.getTargetParticipantCount(),
                m.getParticipants().size()
        );
    }
}
