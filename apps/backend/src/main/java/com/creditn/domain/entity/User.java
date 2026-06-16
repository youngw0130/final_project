package com.creditn.domain.entity;

import com.creditn.domain.entity.common.BaseTimeEntity;
import jakarta.persistence.*;
import lombok.*;

import java.util.ArrayList;
import java.util.List;

/**
 * 서비스 사용자.
 * linkScore : 입금 성실도 기반 대안 신용 점수 (0 ~ 1000, 기본 500).
 */
@Entity
@Table(
    name = "users",
    indexes = {
        @Index(name = "idx_users_username", columnList = "username", unique = true),
        @Index(name = "idx_users_email",    columnList = "email",    unique = true)
    }
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@ToString(exclude = "participants")
public class User extends BaseTimeEntity {

    /* ────────────────── PK ────────────────── */

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "user_id")
    private Long id;

    /* ────────────────── 기본 정보 ────────────────── */

    @Column(nullable = false, unique = true, length = 50)
    private String username;

    @Column(nullable = false, unique = true, length = 100)
    private String email;

    /** BCrypt 해시 저장 */
    @Column(nullable = false)
    private String password;

    @Column(name = "real_name", length = 50)
    private String realName;

    @Column(name = "phone_number", length = 20)
    private String phoneNumber;

    /* ────────────────── 환불 계좌 정보 ────────────────── */

    @Column(name = "refund_bank", length = 30)
    private String refundBank;

    @Column(name = "refund_account_number", length = 30)
    private String refundAccountNumber;

    @Column(name = "refund_account_holder", length = 50)
    private String refundAccountHolder;

    /* ────────────────── 링크 스코어 ────────────────── */

    /**
     * 대안 신용 점수 (0 ~ 1000).
     * - 기한 내 입금 완료 : +10
     * - 모임 리더로 주최   : +20
     * - 기한 초과 미입금   : -10
     */
    @Column(name = "link_score", nullable = false)
    private Integer linkScore = 0;

    @Column(name = "link_score_updated_at")
    private java.time.LocalDateTime linkScoreUpdatedAt;

    /* ────────────────── 연관 관계 ────────────────── */

    /** 참여한 모든 모임 (Participant 중개 엔티티 경유) */
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Participant> participants = new ArrayList<>();

    /* ────────────────── 생성자 ────────────────── */

    @Builder
    public User(String username, String email, String password,
                String realName, String phoneNumber,
                String refundBank, String refundAccountNumber, String refundAccountHolder) {
        this.username              = username;
        this.email                 = email;
        this.password              = password;
        this.realName              = realName;
        this.phoneNumber           = phoneNumber;
        this.refundBank            = refundBank;
        this.refundAccountNumber   = refundAccountNumber;
        this.refundAccountHolder   = refundAccountHolder;
        this.linkScore             = 0;
    }

    /* ────────────────── 도메인 메서드 ────────────────── */

    /**
     * 링크 스코어 증감.
     * @param delta 양수: 가산, 음수: 감점
     */
    public void adjustLinkScore(int delta) {
        int updated = this.linkScore + delta;
        // 0 ~ 1000 범위 클램핑
        this.linkScore          = Math.max(0, Math.min(1000, updated));
        this.linkScoreUpdatedAt = java.time.LocalDateTime.now();
    }

    public void updatePassword(String encodedPassword) {
        this.password = encodedPassword;
    }
}
