# Quick Translator

Translate the text you have selected in any Mac app and replace it with the translation you pick.

Select some text, press **⌥⌘T** (or the shortcut you set) and a popup shows:

- **Apple Translation** — one translation made on your Mac, in about half a second.
- **Claude** — several variants with different registers (natural, formal, informal…), in about 3 seconds.

Click **Usar N** or press the number key to replace the selection. Press **Esc** or click outside to close.

To translate into another language just this once, click the globe icon at the top of the popup and pick a language. Both providers translate again into it; nothing is saved, so the next translation uses your configured languages.

Text in your language goes to your target language, and text in any other language goes to yours. By default your language is Spanish and the target is English; change both from the menu bar icon.

## Requirements

- macOS 26 or later.
- Xcode with Swift 6.2 or later.
- Node.js 18.14 or later (tested with Node.js 26).
- Claude Code installed and signed in (`claude`). Translations use your Claude Code login, so no API key is needed.
- For Apple Translation, both languages of your pair downloaded in System Settings → General → Language & Region → Translation Languages.

## Install

```bash
./scripts/build-app.sh --install
```

This builds the CLI and the app, installs `Quick Translator.app` in `~/Applications` and opens it. Then:

1. Allow it in System Settings → Privacy & Security → **Accessibility**. Without this it cannot read or replace the selection.
2. Optionally, enable the context menu entry in System Settings → Keyboard → Keyboard Shortcuts → Services → Text → *Traducir con Quick Translator*.

To keep the Accessibility permission across rebuilds, sign with a stable code signing certificate (for example a self-signed one created in Keychain Access): `CODESIGN_IDENTITY="My Identity" ./scripts/build-app.sh --install`. Without it the app gets an ad-hoc signature and macOS asks for the permission again after every rebuild.

## Use

- **⌥⌘T** — translate the current selection. Change it in Settings.
- **Right click → Services → Traducir con Quick Translator** — the same from the context menu.
- **Menu bar icon** — *Traducir selección*, *Ajustes…* (⌘,), *Permiso de Accesibilidad…* and *Salir*.

## Settings

**General**

- *Atajo de teclado* — record a new shortcut, or reset it to ⌥⌘T. It needs ⌘, ⌥ or ⌃, and common ⌘ shortcuts such as ⌘C or ⌘Q are refused. If another app already owns the combination, the previous shortcut is kept.
- *Mi idioma* and *Idioma destino* — your language and the language text in it is translated into. Picking the other side's language swaps them. If Apple Translation is missing a language of the new pair, an alert offers to open Language & Region, where *Translation Languages…* downloads it; if Apple does not support the pair at all, only the second provider translates it.

**Proveedor** — the provider of the second popup section, next to Apple Translation:

| Provider | Versions | Needs |
|---|---|---|
| Claude Code | Several registers (natural, formal, informal…) | Your Claude Code login |
| Claude API | Several registers, with Haiku 5.5, Sonnet 5.5 or Opus 5.5 | An API key from platform.claude.com, billed separately |
| DeepL | Formal and informal when the target language supports it, otherwise one | A DeepL API key; free keys end in `:fx` |

- Keys are stored in the macOS Keychain, never in files or preferences.
- *Traducir automáticamente* — when on, the provider is asked with every translation. When off, the popup shows a **Traducir con … (C)** button.
- *Probar* — runs a test translation with the selected provider and shows the time it took or the error.
- The popup shows how long each provider took, so you can compare them.

## CLI

The app uses `quick-translate`, a small CLI in `cli/` that you can also run on its own:

```bash
cd cli && npm install && npm run build

node dist/cli.js "Nos vemos mañana a primera hora"
echo "See you tomorrow" | node dist/cli.js --to French --count 3
```

Options: `--provider claude-code|claude-api|deepl` (keys in `QT_ANTHROPIC_API_KEY` and `QT_DEEPL_AUTH_KEY`), `--api-model <id>` for the Claude API, `--mine <language>` (default Spanish) and `--target <language>` (default English) for the language pair, `--to <language>` to force one target, `--count <1-8>`, `--model <id>` (default `claude-haiku-5-5`), `--effort low|medium|high`, `--server`.

With `--server` it stays running, keeps Claude Code warm and answers one JSON request per line:

```
→ {"id":"1","text":"Nos vemos mañana","mine":"Spanish","target":"English"}
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
