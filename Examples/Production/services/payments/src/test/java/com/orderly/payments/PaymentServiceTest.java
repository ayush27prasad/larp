package com.orderly.payments;

import static org.junit.jupiter.api.Assertions.*;

import java.time.Clock;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;

class PaymentServiceTest {
    static final class FakeGateway implements CardGateway {
        final List<String> charges = new ArrayList<>();

        @Override
        public String charge(String orderId, long amountCents) {
            charges.add(orderId);
            return "ch_" + charges.size();
        }

        @Override
        public void refund(String chargeId) {}
    }

    @Test
    void chargingTheSameOrderTwiceChargesOnce() throws Exception {
        FakeGateway gateway = new FakeGateway();
        PaymentService service = new PaymentService(gateway, Clock.systemUTC());

        service.charge("ord_1", 1_579);
        service.charge("ord_1", 1_579);

        assertEquals(1, gateway.charges.size());
    }

    @Test
    void refundMarksThePaymentRefunded() throws Exception {
        PaymentService service = new PaymentService(new FakeGateway(), Clock.systemUTC());
        service.charge("ord_1", 1_579);

        assertEquals(Payment.Status.REFUNDED, service.refund("ord_1").status());
    }

    @Test
    void rejectsNonPositiveAmounts() {
        PaymentService service = new PaymentService(new FakeGateway(), Clock.systemUTC());
        assertThrows(IllegalArgumentException.class, () -> service.charge("ord_1", 0));
    }
}
