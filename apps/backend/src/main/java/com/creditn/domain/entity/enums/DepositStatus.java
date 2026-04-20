package com.creditn.domain.entity.enums;

/**
 * 참여자의 예치금 입금 상태.
 *
 * <pre>
 * PENDING   → 입금 대기 (기본값)
 * DEPOSITED → 가상계좌 입금 완료 (PortOne 웹훅 수신 후 전환)
 * OVERDUE   → 마감 시간 초과 미입금 → 링크 스코어 감점 트리거
 * REFUNDED  → 넷팅 정산 후 잔액 환급 완료
 * </pre>
 */
public enum DepositStatus {
    PENDING,
    DEPOSITED,
    OVERDUE,
    REFUNDED
}
