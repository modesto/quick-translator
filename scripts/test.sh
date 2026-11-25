#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

(cd "$ROOT/cli" && npm install --silent && npm test)
if [[ "$(uname -s)" == "Darwin" ]]; then
    (cd "$ROOT/app" && swift test)
fi
if command -v dotnet >/dev/null 2>&1; then
    (cd "$ROOT/windows" && dotnet test QuickTranslator.Core.Tests --nologo -v quiet)
fi
