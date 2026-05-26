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
        return ResponseEntity.ok(moimService.joinMoim(user.getUsername(), inviteCode, refundAccountNumber, refundBank));
    }

    @GetMapping("/{moimId}")
    public ResponseEntity<MoimResponse> getMoim(@PathVariable Long moimId) {
        return ResponseEntity.ok(moimService.getMoim(moimId));
    }

    @GetMapping("/my")
    public ResponseEntity<List<MoimResponse>> getMyMoims(
            @AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(moimService.getMyMoims(user.getUsername()));
    }

    @GetMapping("/{moimId}/participants")
    public ResponseEntity<List<ParticipantResponse>> getParticipants(@PathVariable Long moimId) {
        return ResponseEntity.ok(moimService.getParticipants(moimId));
    }

    // 입금 확인 Mock (데모용: PortOne 웹훅 대신 수동 트리거)
    @PostMapping("/{moimId}/deposit/confirm")
    public ResponseEntity<Map<String, String>> confirmDeposit(
            @PathVariable Long moimId,
            @RequestParam Long userId) {
        moimService.confirmDeposit(moimId, userId);
        return ResponseEntity.ok(Map.of("message", "입금 확인 완료"));
    }

    // 넷팅 정산 트리거
    @PostMapping("/{moimId}/settle")
    public ResponseEntity<List<ParticipantResponse>> settle(@PathVariable Long moimId) {
        return ResponseEntity.ok(settlementService.settle(moimId));
    }
}
