#!/usr/bin/env bash
# Rebuilds db/dev.sqlite from the migrations and seed data.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -f db/dev.sqlite
for migration in $(ls db/migrations/*.sql | sort -V); do
    sqlite3 db/dev.sqlite < "$migration"
done
sqlite3 db/dev.sqlite < db/seed.sql
echo "db/dev.sqlite rebuilt"
