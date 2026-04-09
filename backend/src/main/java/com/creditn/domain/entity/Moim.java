package com.creditn.domain.entity;

import com.creditn.domain.entity.common.BaseTimeEntity;
import com.creditn.domain.entity.enums.MoimStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * 에스크로 모임.
 * PortOne을 통해 전용 가상계좌가 발급되며,
 * 모임 종료 시 넷팅 알고리즘으로 잔액을 1/n 환급한다.
 */
@Entity
@Table(
    name = "moim",
    indexes = {
        @Index(name = "idx_moim_status",      columnList = "status"),
        @Index(name = "idx_moim_invite_code", columnList = "invite_code", unique = true),
        @Index(name = "idx_moim_pg_order_id", columnList = "pg_order_id", unique = true)
    }
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@ToString(exclude = {"creator", "participants"})
public class Moim extends BaseTimeEntity {

    /* ────────────────── PK ────────────────── */

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "moim_id")
    private Long id;

    /* ────────────────── 기본 정보 ────────────────── */

    @Column(nullable = false, length = 100)
    private String title;

    @Column(length = 200)
    private String description;

    /** 모임 예정 일시 */
    @Column(name = "scheduled_at")
    private LocalDateTime scheduledAt;

    /** 모임 유형 이모지 (예: 🍻, 🏕️, 🎾) */
    @Column(name = "emoji", length = 10)
    private String emoji;

    /** 6자리 초대 코드 */
    @Column(name = "invite_code", nullable = false, unique = true, length = 10)
    private String inviteCode;

    /* ────────────────── PortOne 가상계좌 ────────────────── */

    /** PortOne PG 주문 ID */
    @Column(name = "pg_order_id", unique = true, length = 100)
    private String pgOrderId;

    /** 발급된 가상계좌 번호 */
    @Column(name = "virtual_account_number", length = 30)
    private String virtualAccountNumber;

    /** 가상계좌 은행명 (예: 토스뱅크) */
    @Column(name = "virtual_account_bank", length = 30)
    private String virtualAccountBank;

    /* ────────────────── 금액 (BigDecimal, KRW) ────────────────── */

    /** 목표 총 에스크로 금액 = 1인 예치금 × 인원 × (1 + bufferRate) */
    @Column(name = "target_amount", nullable = false, precision = 15, scale = 2)
    private BigDecimal targetAmount;

    /** 현재까지 가상계좌에 입금된 총금액 */
    @Column(name = "total_deposited", nullable = false, precision = 15, scale = 2)
    private BigDecimal totalDeposited = BigDecimal.ZERO;

    /** 1인당 기본 예치금 */
    @Column(name = "deposit_per_person", nullable = false, precision = 15, scale = 2)
    private BigDecimal depositPerPerson;

    /**
     * 예치금 버퍼 비율 (기본 7%).
     * 실제 지출이 기본 예치금을 초과할 경우를 대비한 추가 여유 자금.
     * 미사용분은 모임 종료 시 전액 환급된다.
     */
    @Column(name = "buffer_rate", nullable = false, precision = 5, scale = 4)
    private BigDecimal bufferRate = new BigDecimal("0.0700");

    /** 모임 중 QR 결제로 지출된 총금액 */
    @Column(name = "total_spent", nullable = false, precision = 15, scale = 2)
    private BigDecimal totalSpent = BigDecimal.ZERO;

    /* ────────────────── 상태 ────────────────── */

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private MoimStatus status = MoimStatus.OPEN;

    /** 목표 참여 인원 */
    @Column(name = "target_participant_count", nullable = false)
    private Integer targetParticipantCount;

    /* ────────────────── 연관 관계 ────────────────── */

    /** 모임 생성자 */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "creator_id", nullable = false)
    private User creator;

    @OneToMany(mappedBy = "moim", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<Participant> participants = new ArrayList<>();

    /* ────────────────── 생성자 ────────────────── */

    @Builder
    public Moim(String title,
                String description,
                String emoji,
                LocalDateTime scheduledAt,
                BigDecimal depositPerPerson,
                BigDecimal bufferRate,
                Integer targetParticipantCount,
                String inviteCode,
                User creator) {
        this.title                  = title;
        this.description            = description;
        this.emoji                  = emoji;
        this.scheduledAt            = scheduledAt;
        this.depositPerPerson       = depositPerPerson;
        this.bufferRate             = (bufferRate != null) ? bufferRate : new BigDecimal("0.0700");
        this.targetParticipantCount = targetParticipantCount;
        this.inviteCode             = inviteCode;
        this.creator                = creator;
        this.status                 = MoimStatus.OPEN;
        this.totalDeposited         = BigDecimal.ZERO;
        this.totalSpent             = BigDecimal.ZERO;
        this.targetAmount           = calculateTargetAmount(depositPerPerson, targetParticipantCount, this.bufferRate);
    }

    /* ────────────────── 도메인 메서드 ────────────────── */

    /**
     * 목표 에스크로 금액 계산.
     * targetAmount = depositPerPerson × targetParticipantCount × (1 + bufferRate)
     */
    private static BigDecimal calculateTargetAmount(BigDecimal depositPerPerson,
                                                    int participantCount,
                                                    BigDecimal bufferRate) {
        return depositPerPerson
                .multiply(BigDecimal.valueOf(participantCount))
                .multiply(BigDecimal.ONE.add(bufferRate))
                .setScale(2, RoundingMode.HALF_UP);
    }

    /** PortOne 가상계좌 발급 후 정보 저장 */
    public void assignVirtualAccount(String pgOrderId,
                                     String accountNumber,
                                     String bankName) {
        this.pgOrderId             = pgOrderId;
        this.virtualAccountNumber  = accountNumber;
        this.virtualAccountBank    = bankName;
    }

    /** 입금 확인 (PortOne 웹훅 수신 시 호출) */
    public void addDeposit(BigDecimal amount) {
        this.totalDeposited = this.totalDeposited.add(amount);
    }

    /** QR 결제 승인 시 지출 누적 */
    public void addSpent(BigDecimal amount) {
        this.totalSpent = this.totalSpent.add(amount);
    }

    /** 모임 상태 전환 */
    public void changeStatus(MoimStatus newStatus) {
        this.status = newStatus;
    }

    /** 가상계좌 잔액 = 총 입금 - 총 지출 */
    public BigDecimal getBalance() {
        return this.totalDeposited.subtract(this.totalSpent);
    }

    /** 입금률 (%) = totalDeposited / targetAmount × 100 */
    public BigDecimal getDepositRate() {
        if (this.targetAmount.compareTo(BigDecimal.ZERO) == 0) return BigDecimal.ZERO;
        return this.totalDeposited
                .divide(this.targetAmount, 4, RoundingMode.HALF_UP)
                .multiply(BigDecimal.valueOf(100))
                .setScale(2, RoundingMode.HALF_UP);
    }
}
