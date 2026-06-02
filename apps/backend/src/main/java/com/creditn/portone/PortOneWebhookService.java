package com.creditn.portone;

import com.creditn.config.PortOneProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.creditn.service.MoimService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

/**
 * PortOne V2 웹훅 처리 서비스.
 *
 * <p>검증 방식 (svix 호환):
 * <pre>
 * signature = HMAC-SHA256(webhookId + "." + timestamp + "." + rawBody, webhookSecret)
 * header:  webhook-signature: v1,{base64(signature)}
 * </pre>
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class PortOneWebhookService {

    private static final String WEBHOOK_TYPE_PAID              = "Transaction.Paid";
    private static final String WEBHOOK_TYPE_VA_ISSUED         = "Transaction.VirtualAccountIssued";

    private final PortOneProperties props;
    private final ObjectMapper objectMapper;
    private final MoimService moimService;

    /**
     * 웹훅 서명 검증.
     *
     * @param webhookId        webhook-id 헤더
     * @param webhookTimestamp webhook-timestamp 헤더
     * @param signature        webhook-signature 헤더 (v1,<base64> 형식)
     * @param rawBody          원본 요청 본문
     */
    public boolean verifySignature(String webhookId, String webhookTimestamp,
                                   String signature, String rawBody) {
        if (props.getWebhookSecret() == null || props.getWebhookSecret().startsWith("demo")) {
            log.warn("[Webhook] 데모 모드 - 서명 검증 건너뜀");
            return true;
        }

        try {
            String signedContent = webhookId + "." + webhookTimestamp + "." + rawBody;
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(
                    props.getWebhookSecret().getBytes(StandardCharsets.UTF_8),
                    "HmacSHA256"
            ));
            String computed = Base64.getEncoder().encodeToString(
                    mac.doFinal(signedContent.getBytes(StandardCharsets.UTF_8))
            );

            // signature 헤더에서 "v1," 접두사 제거
            for (String part : signature.split(" ")) {
                String stripped = part.startsWith("v1,") ? part.substring(3) : part;
                if (computed.equals(stripped)) return true;
            }
            return false;

        } catch (Exception e) {
            log.error("[Webhook] 서명 검증 중 오류: {}", e.getMessage());
            return false;
        }
    }

    /**
     * 웹훅 이벤트 처리.
     *
     * @param rawBody 원본 요청 본문 (JSON)
     */
    public void handleEvent(String rawBody) {
        try {
            JsonNode root = objectMapper.readTree(rawBody);
            String type   = root.path("type").asText();
            JsonNode data = root.path("data");

            log.info("[Webhook] 이벤트 수신: type={}", type);

            switch (type) {
                case WEBHOOK_TYPE_PAID -> handleTransactionPaid(data);
                case WEBHOOK_TYPE_VA_ISSUED -> handleVirtualAccountIssued(data);
                default -> log.info("[Webhook] 처리 대상 아닌 이벤트 무시: {}", type);
            }

        } catch (Exception e) {
            log.error("[Webhook] 이벤트 처리 실패: {}", e.getMessage(), e);
            throw new IllegalArgumentException("웹훅 처리 실패: " + e.getMessage());
        }
    }

    /** Transaction.Paid — 가상계좌 입금 완료 처리 */
    private void handleTransactionPaid(JsonNode data) {
        String paymentId = data.path("paymentId").asText();
        String status    = data.path("status").asText();

        if (!"PAID".equals(status)) {
            log.info("[Webhook] 미입금 상태 무시: paymentId={}, status={}", paymentId, status);
            return;
        }

        BigDecimal amount = new BigDecimal(data.path("amount").path("total").asText("0"));

        log.info("[Webhook] 입금 확인: paymentId={}, amount={}", paymentId, amount);

        // paymentId 형식: CREDITN-MOIM-{moimId}-{uuid}
        Long moimId = extractMoimId(paymentId);
        if (moimId == null) {
            log.warn("[Webhook] moimId 파싱 실패: paymentId={}", paymentId);
            return;
        }

        // 에스크로 입금액에 해당하는 참여자 확인 처리
        moimService.confirmDepositByAmount(moimId, amount);
    }

    /** Transaction.VirtualAccountIssued — 발급 확인 (정보 로그만) */
    private void handleVirtualAccountIssued(JsonNode data) {
        String paymentId = data.path("paymentId").asText();
        log.info("[Webhook] 가상계좌 발급 확인: paymentId={}", paymentId);
    }

    private Long extractMoimId(String paymentId) {
        try {
            // 형식: CREDITN-MOIM-{moimId}-{uuid}
            String[] parts = paymentId.split("-");
            // CREDITN(0) MOIM(1) {moimId}(2) ...
            if (parts.length >= 3) {
                return Long.parseLong(parts[2]);
            }
            return null;
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
