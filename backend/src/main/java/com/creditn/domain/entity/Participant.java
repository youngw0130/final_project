package com.creditn.domain.entity;

import com.creditn.domain.entity.common.BaseTimeEntity;
import com.creditn.domain.entity.enums.DepositStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;

/**
 * User ↔ Moim 다대다 중개 엔티티.
 *
 * <p>단순 조인 테이블이 아닌 {@code @Entity} 로 승격한 이유:
 * <ul>
 *   <li>depositStatus, depositAmount 등 추가 도메인 속성 보유</li>
 *   <li>넷팅 정산 결과(shareAmount, refundAmount)를 직접 저장</li>
 *   <li>링크 스코어 연산의 기준 데이터 역할</li>
 * </ul>
 */
@Entity
@Table(
    name = "participant",
    uniqueConstraints = {
        @UniqueConstraint(
            name  = "uk_participant_user_moim",
            columnNames = {"user_id", "moim_id"}
        )
    },
    indexes = {
        @Index(name = "idx_participant_moim",   columnList = "moim_id"),
        @Index(name = "idx_participant_user",   columnList = "user_id"),
        @Index(name = "idx_participant_status", columnList = "deposit_status")
    }
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@ToString(exclude = {"user", "moim"})
public class Participant extends BaseTimeEntity {

    /* ────────────────── PK ────────────────── */

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "participant_id")
    private Long id;

    /* ────────────────── 연관 관계 ────────────────── */

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "moim_id", nullable = false)
    private Moim moim;

    /* ────────────────── 예치금 정보 ────────────────── */

    /**
     * 이 참여자가 납부해야 할 1인 예치금.
     * Moim.depositPerPerson 을 참여 시점에 스냅샷으로 저장.
     */
    @Column(name = "deposit_amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal depositAmount;

    @Enumerated(EnumType.STRING)
    @Column(name = "deposit_status", nullable = false, length = 20)
    private DepositStatus depositStatus = DepositStatus.PENDING;

    /** PortOne 웹훅으로 실제 입금이 확인된 시각 */
    @Column(name = "deposited_at")
    private LocalDateTime depositedAt;

    /** 입금 기한 (초과 시 OVERDUE 전환 → 링크 스코어 감점) */
    @Column(name = "deposit_deadline")
    private LocalDateTime depositDeadline;

    /* ────────────────── 넷팅 정산 결과 ────────────────── */

    /**
     * 넷팅 알고리즘 실행 후 확정된 이 참여자의 실제 분담금.
     * shareAmount = totalSpent / participantCount (소수점 반올림 처리)
     */
    @Column(name = "share_amount", precision = 15, scale = 2)
    private BigDecimal shareAmount;

    /**
     * 최종 환급액 = depositAmount - shareAmount.
     * 양수 : 환급받음 / 음수 : 추가 납부 필요 (버퍼 초과 시)
     */
    @Column(name = "refund_amount", precision = 15, scale = 2)
    private BigDecimal refundAmount;

    /* ────────────────── 환급 계좌 ────────────────── */

    @Column(name = "refund_account_number", length = 30)
    private String refundAccountNumber;

    @Column(name = "refund_bank", length = 30)
    private String refundBank;

    /** 환급 완료 시각 */
    @Column(name = "refunded_at")
    private LocalDateTime refundedAt;

    /* ────────────────── 생성자 ────────────────── */

    @Builder
    public Participant(User user,
                       Moim moim,
                       BigDecimal depositAmount,
                       LocalDateTime depositDeadline,
                       String refundAccountNumber,
                       String refundBank) {
        this.user                = user;
        this.moim                = moim;
        this.depositAmount       = depositAmount;
        this.depositDeadline     = depositDeadline;
        this.depositStatus       = DepositStatus.PENDING;
        this.refundAccountNumber = refundAccountNumber;
        this.refundBank          = refundBank;
    }

    /* ────────────────── 도메인 메서드 ────────────────── */

    /**
     * 입금 완료 처리 (PortOne 웹훅 수신 시 호출).
     * User 링크 스코어 가산 로직은 서비스 계층에서 담당.
     */
    public void confirmDeposit() {
        this.depositStatus = DepositStatus.DEPOSITED;
        this.depositedAt   = LocalDateTime.now();
    }

    /**
     * 입금 기한 초과 처리 (스케줄러 호출).
     * User 링크 스코어 감점 로직은 서비스 계층에서 담당.
     */
    public void markOverdue() {
        if (this.depositStatus == DepositStatus.PENDING) {
            this.depositStatus = DepositStatus.OVERDUE;
        }
    }

    /**
     * 넷팅 정산 결과 확정.
     * @param shareAmount 이 참여자의 실제 분담금
     */
    public void applyNetting(BigDecimal shareAmount) {
        this.shareAmount  = shareAmount.setScale(2, RoundingMode.HALF_UP);
        this.refundAmount = this.depositAmount
                .subtract(this.shareAmount)
                .setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * 환급 완료 처리.
     */
    public void completeRefund() {
        this.depositStatus = DepositStatus.REFUNDED;
        this.refundedAt    = LocalDateTime.now();
    }

    /**
     * 입금 완료 여부 확인.
     */
    public boolean isDeposited() {
        return this.depositStatus == DepositStatus.DEPOSITED;
    }

    /**
     * 환급 예정 금액 조회 (정산 전에는 depositAmount 전액).
     */
    public BigDecimal getExpectedRefund() {
        return (this.refundAmount != null) ? this.refundAmount : this.depositAmount;
    }
}
