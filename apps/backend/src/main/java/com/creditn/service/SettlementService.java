package com.creditn.service;

import com.creditn.api.dto.ParticipantResponse;
import com.creditn.domain.entity.Moim;
import com.creditn.domain.entity.Participant;
import com.creditn.domain.entity.enums.DepositStatus;
import com.creditn.domain.entity.enums.MoimStatus;
import com.creditn.domain.repository.MoimRepository;
import com.creditn.domain.repository.ParticipantRepository;
import com.creditn.domain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SettlementService {

    private final MoimRepository moimRepository;
    private final ParticipantRepository participantRepository;
    private final UserRepository userRepository;

    @Transactional
    public List<ParticipantResponse> settle(Long moimId) {
        Moim moim = moimRepository.findById(moimId)
                .orElseThrow(() -> new IllegalArgumentException("모임을 찾을 수 없습니다."));

        if (moim.getStatus() == MoimStatus.CLOSED || moim.getStatus() == MoimStatus.SETTLING) {
            throw new IllegalStateException("이미 정산된 모임입니다.");
        }

        List<Participant> deposited = participantRepository
                .findByMoimIdAndDepositStatus(moimId, DepositStatus.DEPOSITED);

        if (deposited.isEmpty()) {
            throw new IllegalStateException("입금 완료된 참여자가 없습니다.");
        }

        moim.changeStatus(MoimStatus.SETTLING);

        BigDecimal sharePerPerson = moim.getTotalSpent()
                .divide(BigDecimal.valueOf(deposited.size()), 2, RoundingMode.HALF_UP);

        for (Participant p : deposited) {
            p.applyNetting(sharePerPerson);
            // [Mock] 환급 송금 — 실서비스에서는 PortOne 송금 API 호출
            p.completeRefund();
        }

        moim.changeStatus(MoimStatus.CLOSED);
        moimRepository.save(moim);

        return participantRepository.findByMoimId(moimId).stream()
                .map(ParticipantResponse::from)
                .toList();
    }

    @Scheduled(fixedRate = 3_600_000)
    @Transactional
    public void processOverdue() {
        List<Participant> overdue = participantRepository
                .findByDepositStatusAndDepositDeadlineBefore(DepositStatus.PENDING, LocalDateTime.now());
        for (Participant p : overdue) {
            p.markOverdue();
            p.getUser().adjustLinkScore(-10);
            userRepository.save(p.getUser());
        }
    }
}
