package com.orderly.payments;

import java.time.Clock;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

public final class PaymentService {
    private final CardGateway gateway;
    private final Clock clock;
    private final Map<String, Payment> paymentsByOrder = new ConcurrentHashMap<>();

    public PaymentService(CardGateway gateway, Clock clock) {
        this.gateway = gateway;
        this.clock = clock;
    }

    /** Charges an order once. A retry for the same order returns the first payment. */
    public Payment charge(String orderId, long amountCents) throws CardGateway.DeclinedException {
        if (amountCents <= 0) {
            throw new IllegalArgumentException("amount must be positive: " + amountCents);
        }
        Payment existing = paymentsByOrder.get(orderId);
        if (existing != null) {
            return existing;
        }
        String chargeId = gateway.charge(orderId, amountCents);
        Payment payment = new Payment(chargeId, orderId, amountCents, Payment.Status.SUCCEEDED, Instant.now(clock));
        paymentsByOrder.put(orderId, payment);
        return payment;
    }

    public Payment refund(String orderId) {
        Payment payment = find(orderId).orElseThrow(() -> new IllegalStateException("no payment for " + orderId));
        if (payment.status() == Payment.Status.REFUNDED) {
            return payment;
        }
        gateway.refund(payment.chargeId());
        Payment refunded = payment.refunded();
        paymentsByOrder.put(orderId, refunded);
        return refunded;
    }

    public Optional<Payment> find(String orderId) {
        return Optional.ofNullable(paymentsByOrder.get(orderId));
    }
}
