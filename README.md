# Quick Translator

Translate the text you have selected in any Mac app and replace it with the translation you pick.

Select some text, press **⌥⌘T** (or the shortcut you set) and a popup shows:

- **Apple Translation** — one translation made on your Mac, in about half a second.
- **Claude** — several variants with different registers (natural, formal, informal…), in about 3 seconds.

Click **Usar N** or press the number key to replace the selection. Press **Esc** or click outside to close.

Spanish text is translated into English; any other language into Spanish.

## Requirements

- macOS 26 or later.
- Xcode with Swift 6.2 or later.
- Node.js 18.14 or later (tested with Node.js 26).
- Claude Code installed and signed in (`claude`). Translations use your Claude Code login, so no API key is needed.
- For Apple Translation, the Spanish and English languages downloaded in System Settings → General → Language & Region → Translation Languages.

## Install

```bash
./scripts/build-app.sh --install
```

This builds the CLI and the app, installs `Quick Translator.app` in `~/Applications` and opens it. Then:

1. Allow it in System Settings → Privacy & Security → **Accessibility**. Without this it cannot read or replace the selection.
2. Optionally, enable the context menu entry in System Settings → Keyboard → Keyboard Shortcuts → Services → Text → *Traducir con Quick Translator*.

To keep the Accessibility permission across rebuilds, sign with a stable code signing certificate (for example a self-signed one created in Keychain Access): `CODESIGN_IDENTITY="My Identity" ./scripts/build-app.sh --install`. Without it the app gets an ad-hoc signature and macOS asks for the permission again after every rebuild.

## Use

- **⌥⌘T** — translate the current selection. Change it from the menu bar icon.
- **Right click → Services → Traducir con Quick Translator** — the same from the context menu.
- **Menu bar icon**:
  - *Cambiar atajo…* — record a new shortcut, or reset it to ⌥⌘T. It needs ⌘, ⌥ or ⌃, and common ⌘ shortcuts such as ⌘C or ⌘Q are refused. If another app already owns the combination, the previous shortcut is kept.
  - *Traducir con Claude automáticamente* — when on, Claude's variants are requested with every translation. When off, the popup shows a **Traducir con Claude (C)** button and Claude is only called when you press it or the **C** key.
  - *Permiso de Accesibilidad…* — opens the Accessibility settings.

## CLI

The app uses `quick-translate`, a small CLI in `cli/` that you can also run on its own:

```bash
cd cli && npm install && npm run build

node dist/cli.js "Nos vemos mañana a primera hora"
echo "See you tomorrow" | node dist/cli.js --to French --count 3
```

Options: `--to <language>`, `--count <1-8>`, `--model <id>` (default `claude-haiku-5-5`), `--effort low|medium|high`, `--server`.

With `--server` it stays running, keeps Claude Code warm and answers one JSON request per line:

```
→ {"id":"1","text":"Nos vemos mañana"}
← {"id":"1","model":"claude-haiku-5-5","result":{"sourceLanguage":"Spanish","targetLanguage":"English","variants":[{"label":"Natural","text":"See you tomorrow"}]}}
```

## Development

```bash
./scripts/test.sh                  # CLI (node --test) and app (Swift Testing) tests
./scripts/build-app.sh --install   # rebuild and relaunch the app
```

- `cli/` — TypeScript CLI on the Claude Agent SDK.
- `app/Sources/QuickTranslatorCore/` — testable logic shared by the app.
- `app/Sources/QuickTranslator/` — the menu bar app.

See [CLAUDE.md](CLAUDE.md) for architecture notes and contribution rules.
