package com.creditn.api.dto;

import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.math.BigDecimal;

public record CreatePaymentRequest(
        /** PortOne SDK에서 결제 완료 후 수신한 paymentId (서버 사이드 검증에 사용) */
        String portOnePaymentId,
        @NotBlank String merchantName,
        String category,
        @NotNull @Min(1) BigDecimal amount
) {}
