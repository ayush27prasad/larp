# ADR 0001: One repository for all services

**Status:** accepted

## Context
Four services and three clients share one `Order` contract. Changes to it
used to land in four repositories over a week.

## Decision
Keep every service and client in one repository, with the contract in
`proto/orders/v1/orders.proto` as the source of truth.

## Consequences
One pull request changes the contract and every consumer. CI runs each
service's tests on every push, which is slower but catches drift.
