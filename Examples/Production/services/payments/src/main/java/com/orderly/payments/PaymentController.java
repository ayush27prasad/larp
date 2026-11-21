package com.orderly.payments;

import java.util.Map;

/** HTTP surface used by orders-api: POST /charges, POST /refunds. */
public final class PaymentController {
    private final PaymentService service;

    public PaymentController(PaymentService service) {
        this.service = service;
    }

    public Map<String, Object> postCharge(Map<String, Object> body) throws CardGateway.DeclinedException {
        String orderId = (String) body.get("order_id");
        long amountCents = ((Number) body.get("amount_cents")).longValue();
        Payment payment = service.charge(orderId, amountCents);
        return Map.of("charge_id", payment.chargeId(), "status", payment.status().name());
    }

    public Map<String, Object> postRefund(Map<String, Object> body) {
        Payment payment = service.refund((String) body.get("order_id"));
        return Map.of("charge_id", payment.chargeId(), "status", payment.status().name());
    }
}
