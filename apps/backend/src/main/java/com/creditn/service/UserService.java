package com.creditn.service;

import com.creditn.api.dto.LinkScoreHistoryResponse;
import com.creditn.api.dto.UserResponse;
import com.creditn.domain.entity.User;
import com.creditn.domain.entity.enums.LinkScoreReason;
import com.creditn.domain.entity.LinkScoreHistory;
import com.creditn.domain.repository.LinkScoreHistoryRepository;
import com.creditn.domain.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@RequiredArgsConstructor
public class UserService {

    private final UserRepository userRepository;
    private final LinkScoreHistoryRepository historyRepository;

    @Transactional(readOnly = true)
    public UserResponse getProfile(String username) {
        return UserResponse.from(getUser(username));
    }

    @Transactional(readOnly = true)
    public List<LinkScoreHistoryResponse> getLinkScoreHistory(String username) {
        User user = getUser(username);
        return historyRepository.findByUserIdOrderByCreatedAtDesc(user.getId())
                .stream()
                .map(LinkScoreHistoryResponse::from)
                .toList();
    }

    /**
     * 링크 스코어 변경 및 이력 저장 (다른 서비스에서 호출).
     */
    @Transactional
    public void adjustLinkScore(User user, int delta, LinkScoreReason reason, Long moimId) {
        user.adjustLinkScore(delta);
        userRepository.save(user);

        LinkScoreHistory history = LinkScoreHistory.builder()
                .user(user)
                .delta(delta)
                .scoreAfter(user.getLinkScore())
                .reason(reason)
                .moimId(moimId)
                .build();
        historyRepository.save(history);
    }

    private User getUser(String username) {
        return userRepository.findByUsername(username)
                .orElseThrow(() -> new IllegalArgumentException("사용자를 찾을 수 없습니다."));
    }
}
