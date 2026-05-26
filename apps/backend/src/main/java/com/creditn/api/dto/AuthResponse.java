package com.creditn.api.dto;

public record AuthResponse(
        String token,
        Long userId,
        String username,
        Integer linkScore
) {}
