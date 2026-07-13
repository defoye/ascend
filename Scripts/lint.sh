#!/usr/bin/env bash
# Runs SwiftLint against the Ascend sources using the repo's .swiftlint.yml.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "swiftlint not found. Install it with: brew install swiftlint" >&2
  exit 1
fi

swiftlint lint --config "$ROOT_DIR/.swiftlint.yml" --strict
