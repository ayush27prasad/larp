# Architecture

The web and mobile clients talk only to `orders-api`. It prices the order,
reserves stock with `inventory`, charges the card through `payments`, and
publishes an event that `notifier` turns into an email.

```mermaid
sequenceDiagram
    participant C as Client (web / mobile)
    participant O as orders-api
    participant I as inventory
    participant P as payments
    participant N as notifier
    C->>O: POST /orders
    O->>O: calculate_total()
    O->>I: POST /reservations
    I-->>O: reserved
    O->>P: POST /charges
    P-->>O: charge id
    O-->>C: 201 Order(status=PAID)
    O--)N: order.paid event
    N->>C: confirmation email
```

## Order lifecycle

`PENDING` → `RESERVED` → `PAID` → `SHIPPED`, or `CANCELLED` from any state
before `SHIPPED`. A failed charge releases the reservation and cancels.

See [ADR 0001](adr/0001-monorepo.md) for why this is one repository.
