package com.creditn.domain.entity.enums;

/**
 * 모임(에스크로) 진행 상태.
 *
 * <pre>
 * OPEN      → 개설 완료, 가상계좌 발급, 입금 모집 중
 * ACTIVE    → 모임 진행 중 (QR 결제 활성화)
 * SETTLING  → 넷팅 알고리즘 정산 처리 중
 * CLOSED    → 정산 완료, 잔액 환급 완료
 * CANCELLED → 모임 취소 (전액 환급)
 * </pre>
 */
public enum MoimStatus {
    OPEN,
    ACTIVE,
    SETTLING,
    CLOSED,
    CANCELLED
}
