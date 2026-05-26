package com.creditn.service;

import com.creditn.api.dto.CreateMoimRequest;
import com.creditn.api.dto.MoimResponse;
import com.creditn.api.dto.ParticipantResponse;
import com.creditn.domain.entity.Moim;
import com.creditn.domain.entity.Participant;
import com.creditn.domain.entity.User;
import com.creditn.domain.entity.enums.DepositStatus;
import com.creditn.domain.entity.enums.MoimStatus;
import com.creditn.domain.repository.MoimRepository;
import com.creditn.domain.repository.ParticipantRepository;
import com.creditn.domain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Random;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class MoimService {

    private final MoimRepository moimRepository;
    private final ParticipantRepository participantRepository;
    private final UserRepository userRepository;

    private static final String[] MOCK_BANKS = {"토스뱅크", "카카오뱅크", "국민은행", "신한은행", "우리은행"};

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

        // [Mock] PortOne 가상계좌 발급 - 발표용 데모로 즉시 발급된 것처럼 처리
        moim.assignVirtualAccount(
                "PG-" + UUID.randomUUID().toString().substring(0, 12).toUpperCase(),
                generateMockAccountNumber(),
                MOCK_BANKS[new Random().nextInt(MOCK_BANKS.length)]
        );

        moimRepository.save(moim);

        // 생성자도 참여자로 등록
        Participant creatorParticipant = Participant.builder()
                .user(creator)
                .moim(moim)
                .depositAmount(req.depositPerPerson())
                .depositDeadline(LocalDateTime.now().plusDays(3))
                .refundAccountNumber(req.refundAccountNumber())
                .refundBank(req.refundBank())
                .build();
        participantRepository.save(creatorParticipant);

        // 모임 주최 링크 스코어 +20
        creator.adjustLinkScore(20);
        userRepository.save(creator);

        return MoimResponse.from(moim);
    }

    /** 6자리 영숫자 초대코드를 충돌 없을 때까지 생성 */
    private String generateUniqueInviteCode() {
        for (int i = 0; i < 10; i++) {
            String code = UUID.randomUUID().toString().substring(0, 6).toUpperCase();
            if (!moimRepository.findByInviteCode(code).isPresent()) {
                return code;
            }
        }
        throw new IllegalStateException("초대코드 생성 실패. 잠시 후 다시 시도해주세요.");
    }

    /** 12자리 가상계좌 번호 mock */
    private String generateMockAccountNumber() {
        Random r = new Random();
        StringBuilder sb = new StringBuilder();
        for (int i = 0; i < 12; i++) sb.append(r.nextInt(10));
        return sb.toString();
    }

    @Transactional
    public MoimResponse joinMoim(String username, String inviteCode,
                                 String refundAccountNumber, String refundBank) {
        User user = getUser(username);
        Moim moim = moimRepository.findByInviteCode(inviteCode)
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 초대코드입니다."));

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

        return MoimResponse.from(moim);
    }

    @Transactional(readOnly = true)
    public MoimResponse getMoim(Long moimId) {
        return MoimResponse.from(getMoimById(moimId));
    }

    @Transactional(readOnly = true)
    public List<MoimResponse> getMyMoims(String username) {
        User user = getUser(username);
        return participantRepository.findByUserId(user.getId()).stream()
                .map(p -> MoimResponse.from(p.getMoim()))
                .toList();
    }

    @Transactional(readOnly = true)
    public List<ParticipantResponse> getParticipants(Long moimId) {
        return participantRepository.findByMoimId(moimId).stream()
                .map(ParticipantResponse::from)
                .toList();
    }

    // 입금 확인 (PortOne 웹훅 또는 Mock 용)
    @Transactional
    public void confirmDeposit(Long moimId, Long userId) {
        Participant participant = participantRepository.findByUserIdAndMoimId(userId, moimId)
                .orElseThrow(() -> new IllegalArgumentException("참여자를 찾을 수 없습니다."));

        if (participant.getDepositStatus() == DepositStatus.DEPOSITED) return;

        participant.confirmDeposit();
        Moim moim = participant.getMoim();
        moim.addDeposit(participant.getDepositAmount());

        // 기한 내 입금 링크 스코어 +10
        participant.getUser().adjustLinkScore(10);
        userRepository.save(participant.getUser());

        // 모든 참여자가 입금 완료하면 ACTIVE 로 전환 (QR 결제 활성화)
        if (moim.getStatus() == MoimStatus.OPEN && isAllDeposited(moim)) {
            moim.changeStatus(MoimStatus.ACTIVE);
            moimRepository.save(moim);
        }
    }

    private boolean isAllDeposited(Moim moim) {
        List<Participant> all = participantRepository.findByMoimId(moim.getId());
        if (all.isEmpty()) return false;
        return all.stream().allMatch(Participant::isDeposited);
    }

    private User getUser(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
    }

    private Moim getMoimById(Long moimId) {
        return moimRepository.findById(moimId)
                .orElseThrow(() -> new IllegalArgumentException("모임을 찾을 수 없습니다."));
    }
}
