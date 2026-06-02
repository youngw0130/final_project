package com.creditn.api.controller;

import com.creditn.api.dto.LinkScoreHistoryResponse;
import com.creditn.api.dto.UserResponse;
import com.creditn.service.UserService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/users")
@RequiredArgsConstructor
public class UserController {

    private final UserService userService;

    /** 내 프로필 조회 (링크 스코어 포함) */
    @GetMapping("/me")
    public ResponseEntity<UserResponse> getMyProfile(@AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(userService.getProfile(user.getUsername()));
    }

    /** 링크 스코어 변경 이력 조회 */
    @GetMapping("/me/link-score/history")
    public ResponseEntity<List<LinkScoreHistoryResponse>> getLinkScoreHistory(
            @AuthenticationPrincipal UserDetails user) {
        return ResponseEntity.ok(userService.getLinkScoreHistory(user.getUsername()));
    }
}
