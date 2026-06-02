package com.creditn.domain.repository;

import com.creditn.domain.entity.LinkScoreHistory;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface LinkScoreHistoryRepository extends JpaRepository<LinkScoreHistory, Long> {

    List<LinkScoreHistory> findByUserIdOrderByCreatedAtDesc(Long userId);
}
