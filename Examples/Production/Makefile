.PHONY: up down test seed

up:
	docker compose up -d

down:
	docker compose down

test:
	cd services/orders-api && pytest
	cd services/inventory && go test ./...
	cd services/payments && mvn -q test
	cd services/notifier && cargo test
	cd web && npm test

seed:
	./scripts/seed-db.sh
