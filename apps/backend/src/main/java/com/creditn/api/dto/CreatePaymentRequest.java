package com.creditn.api.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.math.BigDecimal;

public record CreatePaymentRequest(
        @NotBlank String merchantName,
        String category,
        @NotNull @Positive BigDecimal amount
) {}
