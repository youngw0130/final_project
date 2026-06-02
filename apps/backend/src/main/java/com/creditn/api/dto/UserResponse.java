package com.creditn.api.dto;

import com.creditn.domain.entity.User;

import java.time.LocalDateTime;

public record UserResponse(
        Long id,
        String username,
        String email,
        String phoneNumber,
        Integer linkScore,
        LocalDateTime linkScoreUpdatedAt
) {
    public static UserResponse from(User user) {
        return new UserResponse(
                user.getId(),
                user.getUsername(),
                user.getEmail(),
                user.getPhoneNumber(),
                user.getLinkScore(),
                user.getLinkScoreUpdatedAt()
        );
    }
}
