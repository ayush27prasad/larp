#!/usr/bin/env bash
# Regenerates Larp.xcodeproj from project.yml.
# Run after pulling changes or whenever files are added or removed.
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "error: xcodegen not found. Install it with: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate
echo "Generated Larp.xcodeproj — open it with: open Larp.xcodeproj"
