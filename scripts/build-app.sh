#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Quick Translator.app"
INSTALL_DIR="$HOME/Applications"

(cd "$ROOT/cli" && npm install --silent && npm run --silent build)
(cd "$ROOT/app" && swift build -c release)

NODE_PATH="$(command -v node)"
CLI_PATH="$ROOT/cli/dist/cli.js"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/app/.build/release/QuickTranslator" "$APP/Contents/MacOS/QuickTranslator"
sed -e "s|__NODE_PATH__|$NODE_PATH|" -e "s|__CLI_PATH__|$CLI_PATH|" \
    "$ROOT/app/Resources/Info.plist.template" > "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

echo "Built: $APP"

if [[ "${1:-}" == "--install" ]]; then
    mkdir -p "$INSTALL_DIR"
    pkill -x QuickTranslator || true
    rm -rf "$INSTALL_DIR/Quick Translator.app"
    cp -R "$APP" "$INSTALL_DIR/"
    /System/Library/CoreServices/pbs -update
    open "$INSTALL_DIR/Quick Translator.app"
    echo "Installed: $INSTALL_DIR/Quick Translator.app"
fi
