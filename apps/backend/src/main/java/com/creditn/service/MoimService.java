package com.creditn.service;

import com.creditn.api.dto.CreateMoimRequest;
import com.creditn.api.dto.MoimResponse;
import com.creditn.api.dto.ParticipantResponse;
import com.creditn.domain.entity.Moim;
import com.creditn.domain.entity.Participant;
import com.creditn.domain.entity.User;
import com.creditn.domain.entity.enums.DepositStatus;
import com.creditn.domain.entity.enums.LinkScoreReason;
import com.creditn.domain.entity.enums.MoimStatus;
import com.creditn.domain.repository.MoimRepository;
import com.creditn.domain.repository.ParticipantRepository;
import com.creditn.domain.repository.UserRepository;
import com.creditn.portone.PortOneClient;
import com.creditn.portone.PortOneApiException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class MoimService {

    private final MoimRepository moimRepository;
    private final ParticipantRepository participantRepository;
    private final UserRepository userRepository;
    private final PortOneClient portOneClient;
    private final UserService userService;

    @Transactional
    public MoimResponse createMoim(String username, CreateMoimRequest req) {
        User creator = getUser(username);
        String inviteCode = generateUniqueInviteCode();

        Moim moim = Moim.builder()
                .title(req.title())
                .description(req.description())
                .emoji(req.emoji())
                .scheduledAt(req.scheduledAt())
                .depositPerPerson(req.depositPerPerson())
                .bufferRate(req.bufferRate())
                .targetParticipantCount(req.targetParticipantCount())
                .inviteCode(inviteCode)
                .creator(creator)
                .build();

        moimRepository.save(moim);

        // PortOne 가상계좌 발급
        try {
            PortOneClient.VirtualAccountInfo va = portOneClient.issueVirtualAccount(
                    moim.getId(),
                    moim.getTargetAmount(),
                    moim.getTitle() + " 에스크로"
            );
            moim.assignVirtualAccount(va.pgOrderId(), va.accountNumber(), va.bank());
        } catch (PortOneApiException e) {
            log.warn("[MoimService] PortOne 가상계좌 발급 실패, Fallback 적용: {}", e.getMessage());
            // Fallback: Mock VA (개발/데모 환경 대비)
            moim.assignVirtualAccount(
                    "CREDITN-MOIM-" + moim.getId() + "-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase(),
                    generateFallbackAccountNumber(),
                    "토스뱅크"
            );
        }

        // 생성자 참여자 등록
        Participant creatorParticipant = Participant.builder()
                .user(creator)
                .moim(moim)
                .depositAmount(req.depositPerPerson())
                .depositDeadline(LocalDateTime.now().plusDays(3))
                .refundAccountNumber(req.refundAccountNumber())
                .refundBank(req.refundBank())
                .build();
        participantRepository.save(creatorParticipant);

        // 링크 스코어 +20 (모임 주최)
        userService.adjustLinkScore(creator, 20, LinkScoreReason.MOIM_CREATED, moim.getId());

        return MoimResponse.from(moim);
    }

    @Transactional
    public MoimResponse joinMoim(String username, String inviteCode,
                                  String refundAccountNumber, String refundBank) {
        User user = getUser(username);
        Moim moim = moimRepository.findByInviteCode(inviteCode)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 초대코드입니다."));

        if (moim.getStatus() == MoimStatus.CANCELLED || moim.getStatus() == MoimStatus.CLOSED) {
            throw new IllegalStateException("참가할 수 없는 모임입니다. (상태: " + moim.getStatus() + ")");
        }

        if (participantRepository.existsByUserIdAndMoimId(user.getId(), moim.getId())) {
            throw new IllegalStateException("이미 참여한 모임입니다.");
        }

        Participant participant = Participant.builder()
                .user(user)
                .moim(moim)
                .depositAmount(moim.getDepositPerPerson())
                .depositDeadline(LocalDateTime.now().plusDays(3))
                .refundAccountNumber(refundAccountNumber)
                .refundBank(refundBank)
                .build();
        participantRepository.save(participant);

        // 링크 스코어 +5 (모임 참가)
        userService.adjustLinkScore(user, LinkScoreReason.MOIM_JOINED.getDefaultDelta(),
                LinkScoreReason.MOIM_JOINED, moim.getId());

        return MoimResponse.from(moim);
    }

    @Transactional(readOnly = true)
    public MoimResponse getMoim(Long moimId) {
        return MoimResponse.from(getMoimById(moimId));
    }

    @Transactional(readOnly = true)
    public List<MoimResponse> getMyMoims(String username) {
        User user = getUser(username);
        return moimRepository.findMoimsByUserId(user.getId()).stream()
                .map(MoimResponse::from)
                .toList();
    }

    @Transactional(readOnly = true)
    public List<ParticipantResponse> getParticipants(Long moimId) {
        return participantRepository.findByMoimId(moimId).stream()
                .map(ParticipantResponse::from)
                .toList();
    }

    /**
     * 입금 확인 (PortOne 웹훅 → 자동 호출, 또는 관리자 수동 트리거).
     *
     * @param moimId 모임 ID
     * @param userId 입금 확인할 참여자 userId
     */
    @Transactional
    public void confirmDeposit(Long moimId, Long userId) {
        Participant participant = participantRepository.findByUserIdAndMoimId(userId, moimId)
                .orElseThrow(() -> new IllegalArgumentException("참여자를 찾을 수 없습니다."));

        if (participant.getDepositStatus() == DepositStatus.DEPOSITED) {
            log.info("[MoimService] 이미 입금 확인된 참여자: userId={}, moimId={}", userId, moimId);
            return;
        }

        participant.confirmDeposit();
        participant.getMoim().addDeposit(participant.getDepositAmount());

        // 링크 스코어 +10 (기한 내 입금)
        if (participant.getDepositDeadline() == null
                || LocalDateTime.now().isBefore(participant.getDepositDeadline())) {
            userService.adjustLinkScore(
                    participant.getUser(), 10, LinkScoreReason.DEPOSIT_ON_TIME, moimId);
        }

        // 전원 입금 완료 시 ACTIVE 전환
        Moim moim = participant.getMoim();
        if (moim.getStatus() == MoimStatus.OPEN && isAllDeposited(moim)) {
            moim.changeStatus(MoimStatus.ACTIVE);
            moimRepository.save(moim);
            log.info("[MoimService] 모임 ACTIVE 전환: moimId={}", moimId);
        }
    }

    /**
     * 웹훅으로 수신한 입금 금액으로 해당 참여자를 찾아 입금 확인.
     * PENDING 상태이면서 depositAmount가 일치하는 첫 번째 참여자를 처리.
     */
    @Transactional
    public void confirmDepositByAmount(Long moimId, BigDecimal amount) {
        List<Participant> pending = participantRepository.findByMoimIdAndDepositStatus(moimId, DepositStatus.PENDING);

        Participant target = pending.stream()
                .filter(p -> p.getDepositAmount().compareTo(amount) == 0)
                .findFirst()
                .orElse(pending.isEmpty() ? null : pending.get(0));

        if (target == null) {
            log.warn("[MoimService] 입금 확인 대상 참여자 없음: moimId={}, amount={}", moimId, amount);
            return;
        }

        confirmDeposit(moimId, target.getUser().getId());
    }

    /**
     * 모임 취소 (OPEN 상태만 가능, 리더만 실행 가능).
     * 입금 완료된 참여자는 PortOne 취소 API로 환급 처리.
     */
    @Transactional
    public void cancelMoim(Long moimId, String username) {
        Moim moim = getMoimById(moimId);
        User requester = getUser(username);

        if (!moim.getCreator().getUsername().equals(requester.getUsername())) {
            throw new IllegalStateException("모임 리더만 취소할 수 있습니다.");
        }
        if (moim.getStatus() == MoimStatus.ACTIVE) {
            throw new IllegalStateException("ACTIVE 상태의 모임은 취소할 수 없습니다. 정산을 먼저 진행해주세요.");
        }
        if (moim.getStatus() == MoimStatus.CLOSED || moim.getStatus() == MoimStatus.CANCELLED) {
            throw new IllegalStateException("이미 종료된 모임입니다.");
        }

        List<Participant> deposited = participantRepository.findByMoimIdAndDepositStatus(moimId, DepositStatus.DEPOSITED);

        // 입금된 참여자 환급 처리
        for (Participant p : deposited) {
            if (p.getRefundAccountNumber() != null && moim.getPgOrderId() != null) {
                try {
                    portOneClient.cancelPayment(
                            moim.getPgOrderId(),
                            p.getDepositAmount(),
                            "모임 취소 환급",
                            p.getRefundBank(),
                            p.getRefundAccountNumber(),
                            p.getUser().getUsername()
                    );
                } catch (PortOneApiException e) {
                    log.error("[MoimService] 취소 환급 실패: userId={}, error={}", p.getUser().getId(), e.getMessage());
                }
            }
            p.completeRefund();
        }

        moim.changeStatus(MoimStatus.CANCELLED);
        moimRepository.save(moim);
        log.info("[MoimService] 모임 취소 완료: moimId={}", moimId);
    }

    private boolean isAllDeposited(Moim moim) {
        List<Participant> all = participantRepository.findByMoimId(moim.getId());
        if (all.isEmpty()) return false;
        return all.stream().allMatch(Participant::isDeposited);
    }

    private String generateUniqueInviteCode() {
        for (int i = 0; i < 10; i++) {
            String code = UUID.randomUUID().toString().substring(0, 6).toUpperCase();
            if (moimRepository.findByInviteCode(code).isEmpty()) return code;
        }
        throw new IllegalStateException("초대코드 생성 실패. 잠시 후 다시 시도해주세요.");
    }

    private String generateFallbackAccountNumber() {
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 12; i++) sb.append((int)(Math.random() * 10));
        return sb.toString();
    }

    private User getUser(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
    }

    public Moim getMoimById(Long moimId) {
        return moimRepository.findById(moimId)
                .orElseThrow(() -> new IllegalArgumentException("모임을 찾을 수 없습니다."));
    }
}
