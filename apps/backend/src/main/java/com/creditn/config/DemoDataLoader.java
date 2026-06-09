package com.creditn.config;

import com.creditn.api.dto.CreateMoimRequest;
import com.creditn.api.dto.CreatePaymentRequest;
import com.creditn.api.dto.SignupRequest;
import com.creditn.service.AuthService;
import com.creditn.service.MoimService;
import com.creditn.service.PaymentService;
import com.creditn.service.SettlementService;
import com.creditn.domain.entity.User;
import com.creditn.domain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Configuration;

import java.math.BigDecimal;
import java.time.LocalDateTime;

/**
 * 발표용 시드 데이터 로더.
 * 서버 부팅 시 데모 계정과 진행 중 모임을 미리 생성해
 * 처음 화면에서 곧바로 시연이 가능하도록 한다.
 *
 * 생성 데이터:
 *  - 5명의 사용자 (감나빗 / minsu / sora / hyunwoo / seoyeon)
 *  - 모임 "라멘야 모임" — 전원 입금 완료 + QR 결제 3건 (ACTIVE)
 *  - 모임 "주말 캠핑 🏕️"   — 일부만 입금 (OPEN, 미입금자 시연)
 *  - 모임 "헬스 PT 🏋️"   — 4명 중 2명만 입금 (OPEN, 입금 현황 시연)
 *  - 모임 "라멘야 모임" — 전원 입금 + 결제 후 정산 완료 (CLOSED, 정산 리포트 시연)
 */
@Configuration
@RequiredArgsConstructor
@Slf4j
public class DemoDataLoader {

    private final AuthService authService;
    private final MoimService moimService;
    private final PaymentService paymentService;
    private final SettlementService settlementService;
    private final UserRepository userRepository;

    CommandLineRunner seed() {
        return args -> {
            if (userRepository.count() > 0) {
                log.info("[DemoDataLoader] 기존 데이터가 있어 시드 생성을 건너뜁니다.");
                return;
            }
            log.info("[DemoDataLoader] 시드 데이터 생성 시작");

            authService.signup(new SignupRequest("감나빗",   "gamnabit@creditn.com", "test1234", "010-1111-2222"));
            authService.signup(new SignupRequest("민수",    "minsu@creditn.com",    "test1234", "010-2222-3333"));
            authService.signup(new SignupRequest("소라",     "sora@creditn.com",     "test1234", "010-3333-4444"));
            authService.signup(new SignupRequest("현우",  "hyunwoo@creditn.com",  "test1234", "010-4444-5555"));
            authService.signup(new SignupRequest("서연",  "seoyeon@creditn.com",  "test1234", "010-5555-6666"));

            var m1 = moimService.createMoim("감나빗",
                    new CreateMoimRequest("라멘야 모임", "부산본점 라멘 회식 에스크로", "🍜",
                            LocalDateTime.now().plusDays(1), 4,
                            new BigDecimal("30000"), new BigDecimal("0.07"),
                            "110-1234-5678", "토스뱅크"));

            moimService.joinMoim("민수",   m1.inviteCode(), "1002-2233-4455", "카카오뱅크");
            moimService.joinMoim("소라",    m1.inviteCode(), "333-44-55555",   "국민은행");
            moimService.joinMoim("현우", m1.inviteCode(), "1234-5678-9012", "신한은행");

            confirmDepositByUsername(m1.id(), "감나빗");
            confirmDepositByUsername(m1.id(), "민수");
            confirmDepositByUsername(m1.id(), "소라");
            confirmDepositByUsername(m1.id(), "현우");

            paymentService.pay(m1.id(), "감나빗", new CreatePaymentRequest(null, "라멘야 부산본점", "식음료", new BigDecimal("18500")));
            paymentService.pay(m1.id(), "감나빗", new CreatePaymentRequest(null, "라멘야 부산본점 사이드", "식음료", new BigDecimal("62000")));
            paymentService.pay(m1.id(), "민수", new CreatePaymentRequest(null, "부산본점 인근 편의점", "식음료", new BigDecimal("24000")));

            var m2 = moimService.createMoim("서연",
                    new CreateMoimRequest("주말 캠핑 🏕️", "양양 서피비치", "🏕️",
                            LocalDateTime.now().plusDays(7), 3,
                            new BigDecimal("80000"), new BigDecimal("0.10"),
                            "1002-9999-0001", "카카오뱅크"));

            moimService.joinMoim("감나빗", m2.inviteCode(), "110-1234-5678", "토스뱅크");
            moimService.joinMoim("현우", m2.inviteCode(), "1234-5678-9012", "신한은행");

            confirmDepositByUsername(m2.id(), "서연");

            /* ── m3: 일부만 입금 (OPEN) ───────────────────────── */
            var m3 = moimService.createMoim("민수",
                    new CreateMoimRequest("헬스 PT 🏋️", "강남 PT 10회권 분담", "🏋️",
                            LocalDateTime.now().plusDays(5), 4,
                            new BigDecimal("50000"), new BigDecimal("0.07"),
                            "1002-2233-4455", "카카오뱅크"));

            moimService.joinMoim("소라",    m3.inviteCode(), "333-44-55555",   "국민은행");
            moimService.joinMoim("서연", m3.inviteCode(), "1002-9999-0001", "카카오뱅크");
            moimService.joinMoim("현우", m3.inviteCode(), "1234-5678-9012", "신한은행");

            confirmDepositByUsername(m3.id(), "민수");
            confirmDepositByUsername(m3.id(), "소라");
            /* seoyeon, hyunwoo: 미입금 → 독촉/입금 버튼 시연용 */

            /* ── m4: 정산 완료 (CLOSED) ───────────────────────── */
            var m4 = moimService.createMoim("현우",
                    new CreateMoimRequest("라멘야 모임", "정산 완료 시연용(전월 건)", "🍜",
                            LocalDateTime.now().minusDays(30), 3,
                            new BigDecimal("25000"), new BigDecimal("0.07"),
                            "1234-5678-9012", "신한은행"));

            moimService.joinMoim("민수", m4.inviteCode(), "1002-2233-4455", "카카오뱅크");
            moimService.joinMoim("소라",  m4.inviteCode(), "333-44-55555",   "국민은행");

            confirmDepositByUsername(m4.id(), "현우");
            confirmDepositByUsername(m4.id(), "민수");
            confirmDepositByUsername(m4.id(), "소라");

            paymentService.pay(m4.id(), "현우", new CreatePaymentRequest(null, "라멘야 부산본점", "식음료", new BigDecimal("40000")));

            settlementService.settle(m4.id(), "현우");

            log.info("[DemoDataLoader] 시드 데이터 생성 완료");
            log.info("  - 데모 로그인: 감나빗 / test1234");
            log.info("  - 시연 모임: ACTIVE m1={}, OPEN m2={}, OPEN m3={}, CLOSED m4={}",
                    m1.id(), m2.id(), m3.id(), m4.id());
        };
    }

    private void confirmDepositByUsername(Long moimId, String username) {
        User u = userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalStateException("seed user not found: " + username));
        moimService.confirmDeposit(moimId, u.getId());
    }

    /** CommandLineRunner를 빈으로 등록 */
    @org.springframework.context.annotation.Bean
    public CommandLineRunner demoSeedRunner() {
        return seed();
    }
}
