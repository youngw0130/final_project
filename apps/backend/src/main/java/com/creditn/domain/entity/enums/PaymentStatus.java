package com.creditn.domain.entity.enums;

/**
 * QR 결제 상태.
 *
 * <pre>
 * APPROVED → 가맹점 결제 승인 완료 (모임 총지출에 반영)
 * CANCELLED → 결제 취소
 * </pre>
 */
public enum PaymentStatus {
    APPROVED,
    CANCELLED
}
