package com.creditn.portone;

import com.creditn.config.PortOneProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.*;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * PortOne V2 REST API 클라이언트.
 *
 * <p>주요 기능:
 * <ul>
 *   <li>가상계좌 발급 (모임 에스크로)</li>
 *   <li>결제 조회·검증 (QR 결제 서버 사이드 검증)</li>
 *   <li>결제 취소·환급 (정산 완료 후 환급)</li>
 * </ul>
 *
 * <p>API 문서: https://developers.portone.io/api/rest-v2
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class PortOneClient {

    private final PortOneProperties props;
    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    /** 가상계좌 발급 결과 */
    public record VirtualAccountInfo(
            String pgOrderId,
            String accountNumber,
            String bank
    ) {}

    /** 결제 조회 결과 */
    public record PaymentInfo(
            String paymentId,
            String status,
            BigDecimal totalAmount
    ) {}

    /**
     * 모임 에스크로 가상계좌 발급.
     *
     * @param moimId    모임 ID (paymentId 생성에 사용)
     * @param amount    목표 에스크로 금액
     * @param orderName 주문명 (예: "라멘야 모임 에스크로")
     * @return 발급된 가상계좌 정보
     */
    public VirtualAccountInfo issueVirtualAccount(Long moimId, BigDecimal amount, String orderName) {
        String paymentId = "CREDITN-MOIM-" + moimId + "-"
                + UUID.randomUUID().toString().replace("-", "").substring(0, 12).toUpperCase();

        ObjectNode body = objectMapper.createObjectNode();
        body.put("storeId", props.getStoreId());
        body.put("channelKey", props.getChannelKey());
        body.put("orderName", orderName);

        ObjectNode amountNode = objectMapper.createObjectNode();
        amountNode.put("total", amount.intValue());
        body.set("amount", amountNode);
        body.put("currency", "KRW");

        // customer.name (PG 필수)
        ObjectNode customer = objectMapper.createObjectNode();
        ObjectNode customerName = objectMapper.createObjectNode();
        customerName.put("full", "크레딧-N 모임");
        customer.set("name", customerName);
        body.set("customer", customer);

        // method.virtualAccount (PortOne V2 구조)
        ObjectNode vaMethod = objectMapper.createObjectNode();
        ObjectNode va = objectMapper.createObjectNode();
        va.put("bank", "SHINHAN");
        ObjectNode expiry = objectMapper.createObjectNode();
        expiry.put("validHours", 72);
        va.set("expiry", expiry);
        ObjectNode option = objectMapper.createObjectNode();
        option.put("type", "NORMAL");
        va.set("option", option);
        va.put("remitteeName", "크레딧-N");
        vaMethod.set("virtualAccount", va);
        body.set("method", vaMethod);

        log.info("[PortOne] 가상계좌 발급 요청: paymentId={}, amount={}", paymentId, amount);

        try {
            // Step 1: 가상계좌 발급
            restTemplate.exchange(
                    props.getBaseUrl() + "/payments/" + paymentId + "/instant",
                    HttpMethod.POST,
                    new HttpEntity<>(body.toString(), authHeaders()),
                    JsonNode.class
            );

            // Step 2: 발급 결과 조회 (instant 응답에 계좌번호 없음, GET으로 조회 필요)
            ResponseEntity<JsonNode> detailRes = restTemplate.exchange(
                    props.getBaseUrl() + "/payments/" + paymentId,
                    HttpMethod.GET,
                    new HttpEntity<>(authHeaders()),
                    JsonNode.class
            );

            JsonNode data = detailRes.getBody();
            if (data == null) throw new PortOneApiException("PortOne 응답이 비어 있습니다.");

            String accountNumber = data.path("method").path("accountNumber").asText();
            String bank          = bankCodeToKorean(data.path("method").path("bank").asText());

            log.info("[PortOne] 가상계좌 발급 완료: paymentId={}, bank={}, accountNumber={}",
                    paymentId, bank, accountNumber);

            return new VirtualAccountInfo(paymentId, accountNumber, bank);

        } catch (HttpClientErrorException e) {
            log.error("[PortOne] 가상계좌 발급 실패 ({}): {}", e.getStatusCode(), e.getResponseBodyAsString());
            throw new PortOneApiException("가상계좌 발급 실패: " + extractMessage(e.getResponseBodyAsString()),
                    e.getStatusCode().value());
        } catch (RestClientException e) {
            log.error("[PortOne] 가상계좌 발급 네트워크 오류: {}", e.getMessage());
            throw new PortOneApiException("PortOne 서버 연결 실패: " + e.getMessage());
        }
    }

    /**
     * 결제 단건 조회 (QR 결제 서버 사이드 검증).
     *
     * @param paymentId PortOne paymentId (Flutter SDK에서 수신)
     * @return 결제 상태 및 금액 정보
     */
    public PaymentInfo verifyPayment(String paymentId) {
        log.info("[PortOne] 결제 검증 요청: paymentId={}", paymentId);

        try {
            ResponseEntity<JsonNode> res = restTemplate.exchange(
                    props.getBaseUrl() + "/payments/" + paymentId,
                    HttpMethod.GET,
                    new HttpEntity<>(authHeaders()),
                    JsonNode.class
            );

            JsonNode data = res.getBody();
            if (data == null) throw new PortOneApiException("결제 정보를 가져올 수 없습니다.");

            String status      = data.path("status").asText();
            BigDecimal total   = new BigDecimal(data.path("amount").path("total").asText("0"));

            log.info("[PortOne] 결제 검증 완료: paymentId={}, status={}, amount={}", paymentId, status, total);
            return new PaymentInfo(paymentId, status, total);

        } catch (HttpClientErrorException e) {
            log.error("[PortOne] 결제 조회 실패 ({}): {}", e.getStatusCode(), e.getResponseBodyAsString());
            throw new PortOneApiException("결제 조회 실패: " + extractMessage(e.getResponseBodyAsString()),
                    e.getStatusCode().value());
        }
    }

    /**
     * 결제 취소 (정산 환급).
     *
     * @param pgOrderId          모임의 PortOne paymentId
     * @param cancelAmount       환급 금액
     * @param reason             취소 사유
     * @param refundBank         환급 계좌 은행
     * @param refundAccountNumber 환급 계좌 번호
     * @param holderName         예금주명
     */
    public void cancelPayment(String pgOrderId, BigDecimal cancelAmount, String reason,
                               String refundBank, String refundAccountNumber, String holderName) {
        log.info("[PortOne] 환급 처리 요청: pgOrderId={}, amount={}, holder={}",
                pgOrderId, cancelAmount, holderName);

        ObjectNode body = objectMapper.createObjectNode();
        body.put("storeId", props.getStoreId());
        body.put("reason", reason);
        body.put("amount", cancelAmount.intValue());

        ObjectNode refundAccount = objectMapper.createObjectNode();
        refundAccount.put("bank", normalizeBankCode(refundBank));
        refundAccount.put("accountNumber", refundAccountNumber);
        refundAccount.put("holderName", holderName);
        body.set("refundAccount", refundAccount);

        try {
            restTemplate.exchange(
                    props.getBaseUrl() + "/payments/" + pgOrderId + "/cancel",
                    HttpMethod.POST,
                    new HttpEntity<>(body.toString(), authHeaders()),
                    JsonNode.class
            );
            log.info("[PortOne] 환급 처리 완료: pgOrderId={}, amount={}", pgOrderId, cancelAmount);

        } catch (HttpClientErrorException e) {
            log.error("[PortOne] 환급 실패 ({}): {}", e.getStatusCode(), e.getResponseBodyAsString());
            throw new PortOneApiException("환급 처리 실패: " + extractMessage(e.getResponseBodyAsString()),
                    e.getStatusCode().value());
        }
    }

    private HttpHeaders authHeaders() {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("Authorization", "PortOne " + props.getApiSecret());
        return headers;
    }

    /** 한글 은행명 → PortOne V2 은행 코드 */
    private String normalizeBankCode(String bank) {
        if (bank == null) return "SHINHAN";
        return switch (bank) {
            case "토스뱅크"  -> "TOSS";
            case "카카오뱅크" -> "KAKAO";
            case "국민은행"  -> "KOOKMIN";
            case "신한은행"  -> "SHINHAN";
            case "우리은행"  -> "WOORI";
            case "하나은행"  -> "HANA";
            case "농협은행"  -> "NONGHYUP";
            case "기업은행"  -> "IBK";
            default         -> bank;
        };
    }

    /** PortOne V2 은행 코드 → 한글 은행명 */
    private String bankCodeToKorean(String code) {
        if (code == null) return "신한은행";
        return switch (code) {
            case "TOSS"     -> "토스뱅크";
            case "KAKAO"    -> "카카오뱅크";
            case "KOOKMIN"  -> "국민은행";
            case "SHINHAN"  -> "신한은행";
            case "WOORI"    -> "우리은행";
            case "HANA"     -> "하나은행";
            case "NONGHYUP" -> "농협은행";
            case "IBK"      -> "기업은행";
            default         -> code;
        };
    }

    private String extractMessage(String responseBody) {
        try {
            JsonNode node = objectMapper.readTree(responseBody);
            return node.path("message").asText(responseBody);
        } catch (Exception e) {
            return responseBody;
        }
    }
}
