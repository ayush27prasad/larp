#!/usr/bin/env bash
# Deploys one service: ./scripts/deploy.sh orders-api staging
set -euo pipefail

service="${1:?service name required}"
env="${2:-staging}"

case "$env" in
  staging|production) ;;
  *) echo "unknown environment: $env" >&2; exit 1 ;;
esac

echo "Building $service…"
docker build -t "orderly/$service:$(git rev-parse --short HEAD)" "services/$service"
echo "Deploying $service to $env"
