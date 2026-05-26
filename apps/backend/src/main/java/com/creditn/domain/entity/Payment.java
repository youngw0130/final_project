package com.creditn.domain.entity;

import com.creditn.domain.entity.common.BaseTimeEntity;
import com.creditn.domain.entity.enums.PaymentStatus;
import jakarta.persistence.*;
import lombok.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 모임 가상계좌에서 가맹점으로 결제된 QR 지출 내역.
 * 발표용 데모이므로 PortOne 실연동 없이 mock 승인으로 동작한다.
 */
@Entity
@Table(
    name = "payment",
    indexes = {
        @Index(name = "idx_payment_moim",   columnList = "moim_id"),
        @Index(name = "idx_payment_status", columnList = "status")
    }
)
@Getter
@NoArgsConstructor(access = AccessLevel.PROTECTED)
@ToString(exclude = "moim")
public class Payment extends BaseTimeEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "payment_id")
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "moim_id", nullable = false)
    private Moim moim;

    /** 결제한 가맹점명 (예: "공차 강남점") */
    @Column(name = "merchant_name", nullable = false, length = 100)
    private String merchantName;

    /** 결제 카테고리 (예: 식음료, 교통, 숙박) */
    @Column(name = "category", length = 30)
    private String category;

    @Column(nullable = false, precision = 15, scale = 2)
    private BigDecimal amount;

    /** QR 결제 승인 시각 */
    @Column(name = "approved_at", nullable = false)
    private LocalDateTime approvedAt;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private PaymentStatus status = PaymentStatus.APPROVED;

    /** 결제를 수행한 참여자 (모임 멤버) */
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "paid_by_user_id")
    private User paidBy;

    @Builder
    public Payment(Moim moim, String merchantName, String category,
                   BigDecimal amount, User paidBy) {
        this.moim         = moim;
        this.merchantName = merchantName;
        this.category     = category;
        this.amount       = amount;
        this.paidBy       = paidBy;
        this.approvedAt   = LocalDateTime.now();
        this.status       = PaymentStatus.APPROVED;
    }

    public void cancel() {
        this.status = PaymentStatus.CANCELLED;
    }
}
