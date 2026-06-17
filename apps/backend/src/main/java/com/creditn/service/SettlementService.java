package com.creditn.service;

import com.creditn.api.dto.ParticipantResponse;
import com.creditn.domain.entity.Moim;
import com.creditn.domain.entity.Participant;
import com.creditn.domain.entity.enums.DepositStatus;
import com.creditn.domain.entity.enums.MoimStatus;
import com.creditn.domain.repository.MoimRepository;
import com.creditn.domain.repository.ParticipantRepository;
import com.creditn.domain.repository.UserRepository;
import com.creditn.portone.PortOneApiException;
import com.creditn.portone.PortOneClient;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;

@Slf4j
@Service
@RequiredArgsConstructor
public class SettlementService {

    private final MoimRepository moimRepository;
    private final ParticipantRepository participantRepository;
    private final UserRepository userRepository;
    private final PortOneClient portOneClient;
    private final UserService userService;

    /**
     * 넷팅 정산 실행.
     *
     * <p>리더만 실행 가능. 처리 순서:
     * <ol>
     *   <li>리더 권한 확인</li>
     *   <li>ACTIVE 상태 확인</li>
     *   <li>shareAmount = totalSpent / 입금 완료 인원</li>
     *   <li>refundAmount = depositAmount - shareAmount</li>
     *   <li>PortOne 취소 API로 환급 (실패 시 로그 기록 후 계속)</li>
     *   <li>모임 CLOSED 전환</li>
     * </ol>
     *
     * @param moimId    정산할 모임 ID
     * @param username  요청 사용자 (리더 검증)
     */
    @Transactional
    public List<ParticipantResponse> settle(Long moimId, String username) {
        Moim moim = moimRepository.findByIdWithDetails(moimId)
                .orElseThrow(() -> new IllegalArgumentException("모임을 찾을 수 없습니다."));

        // 리더 권한 확인
        if (!moim.getCreator().getUsername().equals(username)) {
            throw new IllegalStateException("모임 리더만 정산을 실행할 수 있습니다.");
        }
        if (moim.getStatus() == MoimStatus.CLOSED || moim.getStatus() == MoimStatus.SETTLING) {
            throw new IllegalStateException("이미 정산된 모임입니다.");
        }
        if (moim.getStatus() != MoimStatus.ACTIVE) {
            throw new IllegalStateException(
                    "ACTIVE 상태의 모임만 정산할 수 있습니다. 현재 상태: " + moim.getStatus());
        }

        List<Participant> deposited = participantRepository
                .findByMoimIdAndDepositStatus(moimId, DepositStatus.DEPOSITED);

        if (deposited.isEmpty()) {
            throw new IllegalStateException("입금 완료된 참여자가 없습니다.");
        }

        moim.changeStatus(MoimStatus.SETTLING);

        BigDecimal sharePerPerson = moim.getTotalSpent()
                .divide(BigDecimal.valueOf(deposited.size()), 2, RoundingMode.HALF_UP);

        log.info("[Settlement] 정산 시작: moimId={}, totalSpent={}, participants={}, sharePerPerson={}",
                moimId, moim.getTotalSpent(), deposited.size(), sharePerPerson);

        int refundSuccess = 0;
        int refundFailed  = 0;

        for (Participant p : deposited) {
            p.applyNetting(sharePerPerson);

            BigDecimal refundAmount = p.getRefundAmount();

            // 환급 금액이 0 이하면 추가 납부 없이 바로 완료 처리
            if (refundAmount.compareTo(BigDecimal.ZERO) <= 0) {
                p.completeRefund();
                refundSuccess++;
                continue;
            }

            // PortOne 취소 API로 환급
            if (moim.getPgOrderId() != null
                    && p.getRefundAccountNumber() != null
                    && p.getRefundBank() != null) {
                try {
                    portOneClient.cancelPayment(
                            moim.getPgOrderId(),
                            refundAmount,
                            "크레딧-N 정산 환급",
                            p.getRefundBank(),
                            p.getRefundAccountNumber(),
                            p.getUser().getUsername()
                    );
                    p.completeRefund();
                    refundSuccess++;
                } catch (PortOneApiException e) {
                    log.error("[Settlement] 환급 실패: userId={}, amount={}, error={}",
                            p.getUser().getId(), refundAmount, e.getMessage());
                    refundFailed++;
                }
            } else {
                log.warn("[Settlement] 환급 계좌 정보 없음: userId={}", p.getUser().getId());
                p.completeRefund();
                refundFailed++;
            }
        }

        moim.changeStatus(MoimStatus.CLOSED);
        moimRepository.save(moim);

        log.info("[Settlement] 정산 완료: moimId={}, 성공={}, 실패={}", moimId, refundSuccess, refundFailed);

        return participantRepository.findByMoimId(moimId).stream()
                .map(ParticipantResponse::from)
                .toList();
    }

    /**
     * 1시간마다 입금 기한 초과 참여자를 OVERDUE 처리하고 링크 스코어 감점.
     */
    @Scheduled(fixedRate = 3_600_000)
    @Transactional
    public void processOverdue() {
        List<Participant> overdue = participantRepository
                .findByDepositStatusAndDepositDeadlineBefore(DepositStatus.PENDING, LocalDateTime.now());

        if (!overdue.isEmpty()) {
            log.info("[Settlement] 연체 처리 시작: {}명", overdue.size());
        }

        for (Participant p : overdue) {
            p.markOverdue();
            userService.adjustLinkScore(
                    p.getUser(), -10,
                    com.creditn.domain.entity.enums.LinkScoreReason.DEPOSIT_OVERDUE,
                    p.getMoim().getId()
            );
        }
    }
}
