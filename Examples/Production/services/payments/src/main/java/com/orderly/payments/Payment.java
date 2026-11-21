package com.orderly.payments;

import java.time.Instant;

public record Payment(String chargeId, String orderId, long amountCents, Status status, Instant createdAt) {

    public enum Status { SUCCEEDED, REFUNDED, FAILED }

    public Payment refunded() {
        return new Payment(chargeId, orderId, amountCents, Status.REFUNDED, createdAt);
    }
}
