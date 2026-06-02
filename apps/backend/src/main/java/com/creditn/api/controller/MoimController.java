package com.creditn.api.controller;

import com.creditn.api.dto.CreateMoimRequest;
import com.creditn.api.dto.MoimResponse;
import com.creditn.api.dto.ParticipantResponse;
import com.creditn.service.MoimService;
import com.creditn.service.SettlementService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/moims")
@RequiredArgsConstructor
public class MoimController {

    private final MoimService moimService;
    private final SettlementService settlementService;

    @PostMapping
    public ResponseEntity<MoimResponse> createMoim(
            @AuthenticationPrincipal UserDetails user,
            @Valid @RequestBody CreateMoimRequest req) {
        return ResponseEntity.ok(moimService.createMoim(user.getUsername(), req));
    }

    @PostMapping("/join")
    public ResponseEntity<MoimResponse> joinMoim(
            @AuthenticationPrincipal UserDetails user,
            @RequestParam String inviteCode,
            @RequestParam(required = false) String refundAccountNumber,
            @RequestParam(required = false) String refundBank) {
        return ResponseEntity.ok(
                moimService.joinMoim(user.getUsername(), inviteCode, refundAccountNumber, refundBank));
    }

    @GetMapping("/{moimId}")
    public ResponseEntity<MoimResponse> getMoim(@PathVariable Long moimId) {
        return ResponseEntity.ok(moimService.getMoim(moimId));
    }

    @GetMapping("/my")
    public ResponseEntity<List<MoimResponse>> getMyMoims(@AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(moimService.getMyMoims(user.getUsername()));
    }

    @GetMapping("/{moimId}/participants")
    public ResponseEntity<List<ParticipantResponse>> getParticipants(@PathVariable Long moimId) {
        return ResponseEntity.ok(moimService.getParticipants(moimId));
    }

    /**
     * 입금 확인 (관리자/개발 환경용 수동 트리거).
     * 운영에서는 PortOne 웹훅이 자동으로 처리하므로 이 API는 내부 용도로만 사용.
     */
    @PostMapping("/{moimId}/deposit/confirm")
    public ResponseEntity<Map<String, String>> confirmDeposit(
            @PathVariable Long moimId,
            @RequestParam Long userId) {
        moimService.confirmDeposit(moimId, userId);
        return ResponseEntity.ok(Map.of("message", "입금 확인 완료"));
    }

    /**
     * 넷팅 정산 (리더만 실행 가능).
     */
    @PostMapping("/{moimId}/settle")
    public ResponseEntity<List<ParticipantResponse>> settle(
            @PathVariable Long moimId,
            @AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(settlementService.settle(moimId, user.getUsername()));
    }

    /**
     * 모임 취소 (리더만 가능, OPEN 상태만).
     */
    @PostMapping("/{moimId}/cancel")
    public ResponseEntity<Map<String, String>> cancelMoim(
            @PathVariable Long moimId,
            @AuthenticationPrincipal UserDetails user) {
        moimService.cancelMoim(moimId, user.getUsername());
        return ResponseEntity.ok(Map.of("message", "모임이 취소되었습니다."));
    }
}
