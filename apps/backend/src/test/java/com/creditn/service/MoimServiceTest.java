package com.creditn.service;

import com.creditn.api.dto.CreateMoimRequest;
import com.creditn.api.dto.MoimResponse;
import com.creditn.domain.entity.Moim;
import com.creditn.domain.entity.Participant;
import com.creditn.domain.entity.User;
import com.creditn.domain.entity.enums.DepositStatus;
import com.creditn.domain.entity.enums.MoimStatus;
import com.creditn.domain.repository.MoimRepository;
import com.creditn.domain.repository.ParticipantRepository;
import com.creditn.domain.repository.UserRepository;
import com.creditn.portone.PortOneApiException;
import com.creditn.portone.PortOneClient;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.BDDMockito.*;

@ExtendWith(MockitoExtension.class)
@DisplayName("MoimService 단위 테스트")
class MoimServiceTest {

    @Mock MoimRepository moimRepository;
    @Mock ParticipantRepository participantRepository;
    @Mock UserRepository userRepository;
    @Mock PortOneClient portOneClient;
    @Mock UserService userService;

    @InjectMocks MoimService moimService;

    private User testUser;
    private CreateMoimRequest createRequest;

    @BeforeEach
    void setUp() {
        testUser = User.builder()
                .username("testleader")
                .email("leader@test.com")
                .password("encoded-pw")
                .build();

        createRequest = new CreateMoimRequest(
                "라멘야 모임", "테스트 설명", "🍜",
                LocalDateTime.now().plusDays(7),
                3, new BigDecimal("30000"),
                new BigDecimal("0.07"),
                "110-123-456789", "신한은행"
        );
    }

    @Test
    @DisplayName("모임 생성 성공 - PortOne 가상계좌 발급 성공")
    void createMoim_success_withPortOne() {
        // given
        given(userRepository.findByUsername("testleader")).willReturn(Optional.of(testUser));
        given(moimRepository.findByInviteCode(anyString())).willReturn(Optional.empty());
        given(moimRepository.save(any())).willAnswer(inv -> inv.getArgument(0));
        given(participantRepository.save(any())).willAnswer(inv -> inv.getArgument(0));
        given(portOneClient.issueVirtualAccount(any(), any(), anyString()))
                .willReturn(new PortOneClient.VirtualAccountInfo("CREDITN-MOIM-1-ABCD", "1234567890", "TOSS_BANK"));

        // when
        MoimResponse response = moimService.createMoim("testleader", createRequest);

        // then
        assertThat(response.title()).isEqualTo("라멘야 모임");
        then(portOneClient).should().issueVirtualAccount(any(), any(), anyString());
        then(userService).should().adjustLinkScore(eq(testUser), eq(20), any(), isNull());
    }

    @Test
    @DisplayName("모임 생성 - PortOne API 실패 시 Fallback 적용")
    void createMoim_portOneFails_fallbackApplied() {
        // given
        given(userRepository.findByUsername("testleader")).willReturn(Optional.of(testUser));
        given(moimRepository.findByInviteCode(anyString())).willReturn(Optional.empty());
        given(moimRepository.save(any())).willAnswer(inv -> inv.getArgument(0));
        given(participantRepository.save(any())).willAnswer(inv -> inv.getArgument(0));
        given(portOneClient.issueVirtualAccount(any(), any(), anyString()))
                .willThrow(new PortOneApiException("PortOne 연결 실패"));

        // when - Fallback Mock VA가 적용되어 예외 없이 진행
        MoimResponse response = moimService.createMoim("testleader", createRequest);

        // then
        assertThat(response.title()).isEqualTo("라멘야 모임");
    }

    @Test
    @DisplayName("이미 참여한 모임 재가입 시 예외 발생")
    void joinMoim_alreadyJoined_throwsException() {
        // given
        Moim moim = Moim.builder()
                .title("기존 모임").depositPerPerson(new BigDecimal("20000"))
                .targetParticipantCount(3).inviteCode("ABCDEF").creator(testUser)
                .build();
        given(userRepository.findByUsername("testleader")).willReturn(Optional.of(testUser));
        given(moimRepository.findByInviteCode("ABCDEF")).willReturn(Optional.of(moim));
        given(participantRepository.existsByUserIdAndMoimId(any(), any())).willReturn(true);

        // when & then
        assertThatThrownBy(() -> moimService.joinMoim("testleader", "ABCDEF", "110-xxx", "신한은행"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("이미 참여한 모임");
    }

    @Test
    @DisplayName("입금 확인 성공 - 전원 입금 시 ACTIVE 전환")
    void confirmDeposit_allDeposited_activateMoim() {
        // given
        Moim moim = Moim.builder()
                .title("모임").depositPerPerson(new BigDecimal("20000"))
                .targetParticipantCount(2).inviteCode("CODE01").creator(testUser)
                .build();
        Participant p = Participant.builder()
                .user(testUser).moim(moim)
                .depositAmount(new BigDecimal("20000"))
                .depositDeadline(LocalDateTime.now().plusDays(3))
                .build();

        given(participantRepository.findByUserIdAndMoimId(1L, 1L)).willReturn(Optional.of(p));
        given(participantRepository.findByMoimId(any())).willReturn(List.of(p));
        given(moimRepository.save(any())).willAnswer(inv -> inv.getArgument(0));

        // when
        moimService.confirmDeposit(1L, 1L);

        // then
        assertThat(p.getDepositStatus()).isEqualTo(DepositStatus.DEPOSITED);
        assertThat(moim.getStatus()).isEqualTo(MoimStatus.ACTIVE);
    }

    @Test
    @DisplayName("모임 취소 - 리더가 아닌 경우 예외 발생")
    void cancelMoim_notLeader_throwsException() {
        // given
        User anotherUser = User.builder().username("other").email("other@test.com").password("pw").build();
        Moim moim = Moim.builder()
                .title("모임").depositPerPerson(new BigDecimal("20000"))
                .targetParticipantCount(2).inviteCode("CODE02").creator(testUser)
                .build();

        given(moimRepository.findById(1L)).willReturn(Optional.of(moim));
        given(userRepository.findByUsername("other")).willReturn(Optional.of(anotherUser));

        // when & then
        assertThatThrownBy(() -> moimService.cancelMoim(1L, "other"))
                .isInstanceOf(IllegalStateException.class)
                .hasMessageContaining("모임 리더만 취소할 수 있습니다");
    }
}
