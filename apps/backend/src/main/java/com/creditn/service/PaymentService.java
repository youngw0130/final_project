package com.creditn.service;

import com.creditn.api.dto.CreatePaymentRequest;
import com.creditn.api.dto.PaymentResponse;
import com.creditn.domain.entity.Moim;
import com.creditn.domain.entity.Payment;
import com.creditn.domain.entity.User;
import com.creditn.domain.entity.enums.MoimStatus;
import com.creditn.domain.repository.MoimRepository;
import com.creditn.domain.repository.PaymentRepository;
import com.creditn.domain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

/**
 * 모임 가상계좌 QR 결제 서비스 (mock).
 * 실서비스에서는 PortOne의 결제 승인 API를 호출하지만,
 * 발표용 데모이므로 잔액 검증 후 즉시 승인 처리한다.
 */
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final PaymentRepository paymentRepository;
    private final MoimRepository moimRepository;
    private final UserRepository userRepository;

    @Transactional
    public PaymentResponse pay(Long moimId, String username, CreatePaymentRequest req) {
        Moim moim = moimRepository.findById(moimId)
                .orElseThrow(() -> new IllegalArgumentException("모임을 찾을 수 없습니다."));

        if (moim.getStatus() != MoimStatus.ACTIVE) {
            throw new IllegalStateException(
                "ACTIVE 상태의 모임에서만 결제할 수 있습니다. 현재 상태: " + moim.getStatus());
        }

        if (moim.getBalance().compareTo(req.amount()) < 0) {
            throw new IllegalStateException(
                "가상계좌 잔액 부족 (잔액: " + moim.getBalance() + ", 요청: " + req.amount() + ")");
        }

        User paidBy = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));

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

        return PaymentResponse.from(payment);
    }

    @Transactional(readOnly = true)
    public List<PaymentResponse> getPayments(Long moimId) {
        return paymentRepository.findByMoimIdOrderByApprovedAtDesc(moimId).stream()
                .map(PaymentResponse::from)
                .toList();
    }
}
