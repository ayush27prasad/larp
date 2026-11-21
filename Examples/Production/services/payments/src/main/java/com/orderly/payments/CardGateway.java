package com.orderly.payments;

/** The card processor. Production wires in Stripe; tests use a fake. */
public interface CardGateway {
    /** @return the processor's charge id */
    String charge(String orderId, long amountCents) throws DeclinedException;

    void refund(String chargeId);

    final class DeclinedException extends Exception {
        public DeclinedException(String reason) {
            super(reason);
        }
    }
}
