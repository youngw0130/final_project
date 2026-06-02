package com.creditn.service;

import com.creditn.api.dto.CreatePaymentRequest;
import com.creditn.api.dto.PaymentResponse;
import com.creditn.domain.entity.Moim;
import com.creditn.domain.entity.Payment;
import com.creditn.domain.entity.User;
import com.creditn.domain.entity.enums.MoimStatus;
import com.creditn.domain.repository.MoimRepository;
import com.creditn.domain.repository.ParticipantRepository;
import com.creditn.domain.repository.PaymentRepository;
import com.creditn.domain.repository.UserRepository;
import com.creditn.portone.PortOneApiException;
import com.creditn.portone.PortOneClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final PaymentRepository paymentRepository;
    private final MoimRepository moimRepository;
    private final UserRepository userRepository;
    private final ParticipantRepository participantRepository;
    private final PortOneClient portOneClient;

    /**
     * QR 결제 처리.
     *
     * <p>검증 순서:
     * <ol>
     *   <li>모임 ACTIVE 상태 확인</li>
     *   <li>결제자가 해당 모임 참여자인지 확인</li>
     *   <li>PortOne 결제 검증 (portOnePaymentId가 있는 경우)</li>
     *   <li>잔액 부족 여부 확인</li>
     *   <li>Payment 저장 및 모임 지출 누적</li>
     * </ol>
     */
    @Transactional
    public PaymentResponse pay(Long moimId, String username, CreatePaymentRequest req) {
        Moim moim = moimRepository.findById(moimId)
                .orElseThrow(() -> new IllegalArgumentException("모임을 찾을 수 없습니다."));

        if (moim.getStatus() != MoimStatus.ACTIVE) {
            throw new IllegalStateException(
                    "ACTIVE 상태의 모임에서만 결제할 수 있습니다. 현재 상태: " + moim.getStatus());
        }

        User paidBy = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));

        // 모임 참여자 검증
        if (!participantRepository.existsByUserIdAndMoimId(paidBy.getId(), moimId)) {
            throw new IllegalStateException("해당 모임의 참여자만 결제할 수 있습니다.");
        }

        // PortOne 결제 검증 (portOnePaymentId 제공 시)
        if (req.portOnePaymentId() != null && !req.portOnePaymentId().isBlank()) {
            verifyPortOnePayment(req.portOnePaymentId(), req.amount());
        } else {
            log.warn("[PaymentService] portOnePaymentId 없이 결제 처리: moimId={}, user={}", moimId, username);
        }

        // 잔액 확인
        if (moim.getBalance().compareTo(req.amount()) < 0) {
            throw new IllegalStateException(
                    "가상계좌 잔액 부족 (잔액: " + moim.getBalance() + "원, 요청: " + req.amount() + "원)");
        }

        Payment payment = Payment.builder()
                .moim(moim)
                .merchantName(req.merchantName())
                .category(req.category())
                .amount(req.amount())
                .paidBy(paidBy)
                .build();
        paymentRepository.save(payment);
        moim.addSpent(req.amount());
        moimRepository.save(moim);

        log.info("[PaymentService] 결제 완료: moimId={}, amount={}, merchant={}",
                moimId, req.amount(), req.merchantName());

        return PaymentResponse.from(payment);
    }

    @Transactional(readOnly = true)
    public List<PaymentResponse> getPayments(Long moimId) {
        return paymentRepository.findByMoimIdOrderByApprovedAtDesc(moimId).stream()
                .map(PaymentResponse::from)
                .toList();
    }

    private void verifyPortOnePayment(String portOnePaymentId, java.math.BigDecimal expectedAmount) {
        try {
            PortOneClient.PaymentInfo info = portOneClient.verifyPayment(portOnePaymentId);

            if (!"PAID".equals(info.status())) {
                throw new IllegalStateException(
                        "결제가 완료되지 않았습니다. PortOne 상태: " + info.status());
            }
            if (info.totalAmount().compareTo(expectedAmount) != 0) {
                throw new IllegalStateException(
                        "결제 금액이 일치하지 않습니다. (PortOne: " + info.totalAmount()
                                + "원, 요청: " + expectedAmount + "원)");
            }

            log.info("[PaymentService] PortOne 결제 검증 완료: paymentId={}", portOnePaymentId);

        } catch (PortOneApiException e) {
            log.warn("[PaymentService] PortOne 검증 실패, 요청 계속 진행: {}", e.getMessage());
        }
    }
}
