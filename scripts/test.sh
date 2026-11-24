#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

(cd "$ROOT/cli" && npm install --silent && npm test)
(cd "$ROOT/app" && swift test)
