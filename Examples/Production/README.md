# Orderly

A small but realistic order-management system, kept in the larp repository as
the project larp is tested against. It is not meant to run; it is meant to be
read, navigated, reviewed and diffed.

| Path | Language | What it is |
|---|---|---|
| `services/orders-api` | Python (FastAPI) | Public API: create and list orders, pricing |
| `services/inventory` | Go | Stock levels and reservations |
| `services/payments` | Java | Charges and refunds |
| `services/notifier` | Rust | Order emails |
| `web` | TypeScript + React | Customer dashboard |
| `mobile/ios` | Swift (SwiftUI) | iOS app |
| `mobile/android` | Kotlin | Android app |
| `db` | SQL + SQLite | Schema migrations, seed data, a dev database |
| `proto` | Protocol Buffers | The shared order contract |
| `config`, `data` | YAML, JSON, TOML | Settings, feature flags, product catalogue |

Every service speaks the same `Order`: `id`, `customer_id`, `items`,
`status`, `total_cents`. Following it across languages is the point.

## Things this project exercises in larp

- **Navigation and find-usages:** `calculate_total` (Python), `Reserve` (Go),
  `PaymentService.charge` (Java), `OrderStatus` everywhere.
- **Natural sort:** `db/migrations/V2__…` must come before `V10__…`.
- **Encodings:** `legacy/latin1-notes.txt` is Latin-1 and must open and save as such.
- **Refusals:** `db/dev.sqlite` is binary.
- **JSON viewer:** `data/catalog.json` is large and deeply nested.
- **Database viewer:** `db/dev.sqlite`, built from `db/migrations` and `db/seed.sql`.
- **Diagrams:** `docs/architecture.md` carries a Mermaid diagram.
