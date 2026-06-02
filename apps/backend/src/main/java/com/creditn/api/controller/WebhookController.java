package com.creditn.api.controller;

import com.creditn.portone.PortOneWebhookService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * PortOne V2 웹훅 수신 컨트롤러.
 *
 * <p>SecurityConfig에서 인증 없이 접근 가능하도록 허용.
 * 서명 검증으로 요청의 정당성을 확인한다.
 */
@Slf4j
@RestController
@RequestMapping("/api/webhook")
@RequiredArgsConstructor
public class WebhookController {

    private final PortOneWebhookService webhookService;

    /**
     * POST /api/webhook/portone
     *
     * <p>PortOne이 전송하는 웹훅 이벤트를 수신한다.
     * 서명 검증 실패 시 400 반환 (재시도 방지).
     */
    @PostMapping("/portone")
    public ResponseEntity<Map<String, String>> handlePortOneWebhook(
            @RequestHeader(value = "webhook-id",        required = false, defaultValue = "") String webhookId,
            @RequestHeader(value = "webhook-timestamp", required = false, defaultValue = "") String webhookTimestamp,
            @RequestHeader(value = "webhook-signature", required = false, defaultValue = "") String signature,
            @RequestBody String rawBody) {

        log.info("[Webhook] 수신: id={}, timestamp={}", webhookId, webhookTimestamp);

        // 서명 검증
        if (!webhookService.verifySignature(webhookId, webhookTimestamp, signature, rawBody)) {
            log.warn("[Webhook] 서명 검증 실패 - 요청 거부");
            return ResponseEntity.badRequest().body(Map.of("error", "Invalid signature"));
        }

        webhookService.handleEvent(rawBody);
        return ResponseEntity.ok(Map.of("message", "ok"));
    }
}
