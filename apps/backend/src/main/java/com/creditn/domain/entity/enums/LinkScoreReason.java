package com.creditn.domain.entity.enums;

public enum LinkScoreReason {
    MOIM_CREATED("모임 주최", +20),
    DEPOSIT_ON_TIME("기한 내 입금", +10),
    DEPOSIT_OVERDUE("입금 기한 초과", -10),
    MOIM_JOINED("모임 참가", +5);

    private final String description;
    private final int defaultDelta;

    LinkScoreReason(String description, int defaultDelta) {
        this.description  = description;
        this.defaultDelta = defaultDelta;
    }

    public String getDescription() { return description; }
    public int getDefaultDelta()   { return defaultDelta; }
}
