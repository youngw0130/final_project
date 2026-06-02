package com.creditn.service;

import com.creditn.api.dto.AuthResponse;
import com.creditn.api.dto.LoginRequest;
import com.creditn.api.dto.SignupRequest;
import com.creditn.domain.entity.User;
import com.creditn.domain.repository.UserRepository;
import com.creditn.security.JwtUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.BDDMockito.*;

@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
@DisplayName("AuthService 단위 테스트")
class AuthServiceTest {

    @Mock UserRepository userRepository;
    @Mock PasswordEncoder passwordEncoder;
    @Mock JwtUtil jwtUtil;

    @InjectMocks AuthService authService;

    @BeforeEach
    void setUp() {
        given(jwtUtil.generateToken(anyString())).willReturn("mock-jwt-token");
    }

    @Test
    @DisplayName("회원가입 성공")
    void signup_success() {
        // given
        SignupRequest req = new SignupRequest("testuser", "test@email.com", "password123", "010-0000-0000");
        given(userRepository.existsByUsername("testuser")).willReturn(false);
        given(userRepository.existsByEmail("test@email.com")).willReturn(false);
        given(passwordEncoder.encode("password123")).willReturn("encoded-password");
        given(userRepository.save(any(User.class))).willAnswer(inv -> inv.getArgument(0));

        // when
        AuthResponse response = authService.signup(req);

        // then
        assertThat(response.token()).isEqualTo("mock-jwt-token");
        assertThat(response.username()).isEqualTo("testuser");
        assertThat(response.linkScore()).isEqualTo(500);
    }

    @Test
    @DisplayName("중복 아이디로 회원가입 시 예외 발생")
    void signup_duplicateUsername_throwsException() {
        // given
        SignupRequest req = new SignupRequest("existingUser", "new@email.com", "password123", null);
        given(userRepository.existsByUsername("existingUser")).willReturn(true);

        // when & then
        assertThatThrownBy(() -> authService.signup(req))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("이미 사용 중인 아이디");
    }

    @Test
    @DisplayName("중복 이메일로 회원가입 시 예외 발생")
    void signup_duplicateEmail_throwsException() {
        // given
        SignupRequest req = new SignupRequest("newuser", "existing@email.com", "password123", null);
        given(userRepository.existsByUsername("newuser")).willReturn(false);
        given(userRepository.existsByEmail("existing@email.com")).willReturn(true);

        // when & then
        assertThatThrownBy(() -> authService.signup(req))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("이미 사용 중인 이메일");
    }

    @Test
    @DisplayName("로그인 성공")
    void login_success() {
        // given
        User user = User.builder()
                .username("testuser")
                .email("test@email.com")
                .password("encoded-password")
                .build();
        LoginRequest req = new LoginRequest("testuser", "password123");
        given(userRepository.findByUsername("testuser")).willReturn(Optional.of(user));
        given(passwordEncoder.matches("password123", "encoded-password")).willReturn(true);

        // when
        AuthResponse response = authService.login(req);

        // then
        assertThat(response.token()).isEqualTo("mock-jwt-token");
        assertThat(response.username()).isEqualTo("testuser");
    }

    @Test
    @DisplayName("존재하지 않는 사용자 로그인 시 예외 발생")
    void login_userNotFound_throwsException() {
        // given
        LoginRequest req = new LoginRequest("notexist", "password123");
        given(userRepository.findByUsername("notexist")).willReturn(Optional.empty());

        // when & then
        assertThatThrownBy(() -> authService.login(req))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("존재하지 않는 사용자");
    }

    @Test
    @DisplayName("비밀번호 불일치 시 예외 발생")
    void login_wrongPassword_throwsException() {
        // given
        User user = User.builder()
                .username("testuser")
                .email("test@email.com")
                .password("encoded-password")
                .build();
        LoginRequest req = new LoginRequest("testuser", "wrongpassword");
        given(userRepository.findByUsername("testuser")).willReturn(Optional.of(user));
        given(passwordEncoder.matches("wrongpassword", "encoded-password")).willReturn(false);

        // when & then
        assertThatThrownBy(() -> authService.login(req))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("비밀번호가 올바르지 않습니다");
    }
}
