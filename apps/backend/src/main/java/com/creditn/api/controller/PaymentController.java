package com.creditn.api.controller;

import com.creditn.api.dto.CreatePaymentRequest;
import com.creditn.api.dto.PaymentResponse;
import com.creditn.service.PaymentService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/moims/{moimId}/payments")
@RequiredArgsConstructor
public class PaymentController {

    private final PaymentService paymentService;

    @PostMapping
    public ResponseEntity<PaymentResponse> pay(
            @AuthenticationPrincipal UserDetails user,
            @PathVariable Long moimId,
            @Valid @RequestBody CreatePaymentRequest req) {
        return ResponseEntity.ok(paymentService.pay(moimId, user.getUsername(), req));
    }

    @GetMapping
    public ResponseEntity<List<PaymentResponse>> getPayments(@PathVariable Long moimId) {
        return ResponseEntity.ok(paymentService.getPayments(moimId));
    }
}
