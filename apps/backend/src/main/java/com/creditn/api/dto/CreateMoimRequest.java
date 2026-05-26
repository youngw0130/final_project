package com.creditn.api.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public record CreateMoimRequest(
        @NotBlank String title,
        String description,
        String emoji,
        LocalDateTime scheduledAt,
        @NotNull @Min(1) Integer targetParticipantCount,
        @NotNull BigDecimal depositPerPerson,
        BigDecimal bufferRate,
        String refundAccountNumber,
        String refundBank
) {}
