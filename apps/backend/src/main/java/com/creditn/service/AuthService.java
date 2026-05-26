package com.creditn.service;

import com.creditn.api.dto.AuthResponse;
import com.creditn.api.dto.LoginRequest;
import com.creditn.api.dto.SignupRequest;
import com.creditn.domain.entity.User;
import com.creditn.domain.repository.UserRepository;
import com.creditn.security.JwtUtil;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;

    @Transactional
    public AuthResponse signup(SignupRequest req) {
        if (userRepository.existsByUsername(req.username())) {
            throw new IllegalArgumentException("이미 사용 중인 아이디입니다.");
        }
        if (userRepository.existsByEmail(req.email())) {
            throw new IllegalArgumentException("이미 사용 중인 이메일입니다.");
        }
        User user = User.builder()
                .username(req.username())
                .email(req.email())
                .password(passwordEncoder.encode(req.password()))
                .phoneNumber(req.phoneNumber())
                .build();
        userRepository.save(user);
        String token = jwtUtil.generateToken(user.getUsername());
        return new AuthResponse(token, user.getId(), user.getUsername(), user.getLinkScore());
    }

    @Transactional(readOnly = true)
    public AuthResponse login(LoginRequest req) {
        User user = userRepository.findByUsername(req.username())
                .orElseThrow(() -> new IllegalArgumentException("존재하지 않는 사용자입니다."));
        if (!passwordEncoder.matches(req.password(), user.getPassword())) {
            throw new IllegalArgumentException("비밀번호가 올바르지 않습니다.");
        }
        String token = jwtUtil.generateToken(user.getUsername());
        return new AuthResponse(token, user.getId(), user.getUsername(), user.getLinkScore());
    }
}
