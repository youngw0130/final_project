package com.creditn.api.dto;

import com.creditn.domain.entity.LinkScoreHistory;

import java.time.LocalDateTime;

public record LinkScoreHistoryResponse(
        Long id,
        int delta,
        int scoreAfter,
        String reason,
        String reasonDescription,
        Long moimId,
        LocalDateTime createdAt
) {
    public static LinkScoreHistoryResponse from(LinkScoreHistory h) {
        return new LinkScoreHistoryResponse(
                h.getId(),
                h.getDelta(),
                h.getScoreAfter(),
                h.getReason().name(),
                h.getReason().getDescription(),
                h.getMoimId(),
                h.getCreatedAt()
        );
    }
}
