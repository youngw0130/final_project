package com.creditn.domain.entity;

import com.creditn.domain.entity.enums.LinkScoreReason;
import jakarta.persistence.*;
import lombok.*;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

/**
 * 링크 스코어 변경 이력.
 * 언제, 왜, 얼마나 점수가 바뀌었는지 추적한다.
 */
@Entity
@Table(
    name = "link_score_history",
    indexes = {
        @Index(name = "idx_lsh_user_created", columnList = "user_id, created_at")
    }
)
@EntityListeners(AuditingEntityListener.class)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
public class LinkScoreHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "history_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    /** 점수 변화량 (양수: 증가, 음수: 감소) */
    @Column(nullable = false)
    private int delta;

    /** 변경 후 점수 */
    @Column(name = "score_after", nullable = false)
    private int scoreAfter;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private LinkScoreReason reason;

    /** 관련 모임 ID (nullable) */
    @Column(name = "moim_id")
    private Long moimId;

    @CreatedDate
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Builder
    public LinkScoreHistory(User user, int delta, int scoreAfter,
                             LinkScoreReason reason, Long moimId) {
        this.user       = user;
        this.delta      = delta;
        this.scoreAfter = scoreAfter;
        this.reason     = reason;
        this.moimId     = moimId;
    }
}
