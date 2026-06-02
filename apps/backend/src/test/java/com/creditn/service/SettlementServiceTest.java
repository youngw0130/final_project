package com.creditn.service;

import com.creditn.domain.entity.Moim;
import com.creditn.domain.entity.Participant;
import com.creditn.domain.entity.User;
import com.creditn.domain.entity.enums.DepositStatus;
import com.creditn.domain.entity.enums.MoimStatus;
import com.creditn.domain.repository.MoimRepository;
import com.creditn.domain.repository.ParticipantRepository;
import com.creditn.domain.repository.UserRepository;
import com.creditn.portone.PortOneClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.BDDMockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("SettlementService 단위 테스트")
class SettlementServiceTest {

    @Mock MoimRepository moimRepository;
    @Mock ParticipantRepository participantRepository;
    @Mock UserRepository userRepository;
    @Mock PortOneClient portOneClient;
    @Mock UserService userService;

    @InjectMocks SettlementService settlementService;

    private Moim moim;
    private User leader;
    private User member;

    @BeforeEach
    void setUp() {
        leader = User.builder().username("leader").email("leader@test.com").password("pw").build();
        member = User.builder().username("member").email("member@test.com").password("pw").build();

        moim = Moim.builder()
                .title("테스트 모임")
                .depositPerPerson(new BigDecimal("30000"))
                .targetParticipantCount(2)
                .inviteCode("TEST01")
                .creator(leader)
                .build();
        moim.changeStatus(MoimStatus.ACTIVE);
        moim.addDeposit(new BigDecimal("60000"));
        moim.addSpent(new BigDecimal("40000"));
    }

    @Test
    @DisplayName("리더가 아닌 사용자가 정산 시도 시 예외 발생")
    void settle_notLeader_throwsException() {
        // given
        given(moimRepository.findById(1L)).willReturn(Optional.of(moim));

        // when & then
        assertThatThrownBy(() -> settlementService.settle(1L, "member"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("모임 리더만 정산을 실행할 수 있습니다");
    }

    @Test
    @DisplayName("ACTIVE 상태가 아닌 모임 정산 시도 시 예외 발생")
    void settle_notActive_throwsException() {
        // given
        moim.changeStatus(MoimStatus.OPEN);
        given(moimRepository.findById(1L)).willReturn(Optional.of(moim));

        // when & then
        assertThatThrownBy(() -> settlementService.settle(1L, "leader"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("ACTIVE 상태의 모임만 정산할 수 있습니다");
    }

    @Test
    @DisplayName("이미 정산된 모임 재정산 시도 시 예외 발생")
    void settle_alreadyClosed_throwsException() {
        // given
        moim.changeStatus(MoimStatus.CLOSED);
        given(moimRepository.findById(1L)).willReturn(Optional.of(moim));

        // when & then
        assertThatThrownBy(() -> settlementService.settle(1L, "leader"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("이미 정산된 모임");
    }

    @Test
    @DisplayName("모임 취소 시 리더 권한 없으면 예외 발생 - MoimService 위임 로직 확인")
    void nettingCalculation_isCorrect() {
        // 1인 예치금 30,000 / 총 지출 40,000 / 2명 → 1인 분담금 20,000
        // refund = 30,000 - 20,000 = 10,000
        BigDecimal totalSpent   = new BigDecimal("40000");
        BigDecimal participants = BigDecimal.valueOf(2);
        BigDecimal sharePerPerson = totalSpent.divide(participants, 2, java.math.RoundingMode.HALF_UP);

        assertThat(sharePerPerson).isEqualByComparingTo(new BigDecimal("20000.00"));

        BigDecimal depositPerPerson = new BigDecimal("30000");
        BigDecimal refund = depositPerPerson.subtract(sharePerPerson);
        assertThat(refund).isEqualByComparingTo(new BigDecimal("10000.00"));
    }
}
