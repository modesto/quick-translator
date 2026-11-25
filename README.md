# Quick Translator

Translate the text you have selected in any Mac app and replace it with the translation you pick.

Select some text, press **⌥⌘T** (or the shortcut you set) and a popup shows:

- **Apple Translation** — one translation made on your Mac, in about half a second.
- **Claude** — several variants with different registers (natural, formal, informal…), in about 3 seconds.

Click **Usar N** or press the number key to replace the selection. Press **Esc** or click outside to close.

To translate into another language just this once, click the globe icon at the top of the popup and pick a language. Both providers translate again into it; nothing is saved, so the next translation uses your configured languages.

Text in your language goes to your target language, and text in any other language goes to yours. By default your language is Spanish and the target is English; change both in Settings.

The app itself is shown in your language when it is Spanish, English, French, German, Italian or Portuguese, and in English otherwise.

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

### Keep the Accessibility permission across rebuilds

macOS ties the Accessibility permission to the app's signature. Without a certificate the app gets an ad-hoc signature that changes on every build, so macOS asks for the permission again after each rebuild. A self-signed certificate fixes that, and you only create it once:

1. Open **Keychain Access** (`/System/Library/CoreServices/Applications/Keychain Access.app`; in recent macOS versions it is no longer in Utilities).
2. Choose **Keychain Access → Certificate Assistant → Create a Certificate…**
3. Enter a name, for example `Quick Translator Dev`. Set **Identity Type** to *Self Signed Root* and **Certificate Type** to *Code Signing*, then click **Create**.
4. Double-click the new certificate in the *login* keychain, open **Trust** and set **Code Signing** to *Always Trust*. Close the window and enter your password.
5. Check that it is listed:

   ```bash
   security find-identity -v -p codesigning
   ```

6. Build with it, and add the variable to your shell profile (`~/.zshrc`) so every build uses it:

   ```bash
   export CODESIGN_IDENTITY="Quick Translator Dev"
   ./scripts/build-app.sh --install
   ```

The first build may ask whether `codesign` can use the certificate's key; choose **Always Allow**. If the variable is unset, or the certificate is not found, the script falls back to an ad-hoc signature.

The certificate only works on your Mac, which is all a local build needs. To share the app with other people you would need an Apple Developer ID certificate and notarization.

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
| OpenAI | Several registers, with GPT-6 Luna, GPT-6.1 Terra, GPT-6.2 Sol or any model of an OpenAI-compatible server | An API key from platform.openai.com, billed separately; optional on compatible servers |
| DeepL | Formal and informal when the target language supports it, otherwise one | A DeepL API key; free keys end in `:fx` |

- *URL del API* (OpenAI) — leave it empty for OpenAI, or point it at an OpenAI-compatible server such as Ollama (`http://localhost:11434/v1`), OpenRouter or Groq. OpenAI is called through the Responses API, other servers through Chat Completions.
- Keys are stored in the macOS Keychain, never in files or preferences.
- *Traducir automáticamente* — when on, the provider is asked with every translation. When off, the popup shows a **Traducir con … (C)** button.
- *Probar* — runs a test translation with the selected provider and shows the time it took or the error.
- The popup shows how long each provider took, so you can compare them.

## Windows

A Windows version lives in `windows/` (.NET 10, WPF). It works like the Mac app, with these differences:

- No Apple Translation: the popup shows only the configured provider (Claude Code, Claude API, OpenAI or DeepL).
- The default shortcut is **Ctrl+Alt+T**. It lives in the notification area (tray); click the icon for Settings, right-click for the menu.
- It reads the selection by sending **Ctrl+C** and pastes with **Ctrl+V**, restoring the clipboard both times. No permission is needed, but Windows does not let it send keys to apps running as administrator unless it runs as administrator too.
- Keys are stored in Windows Credential Manager; settings in `%APPDATA%\QuickTranslator\settings.json`.
- Settings → General can open it when you sign in to Windows.

Requirements: Windows 10 or 11, the .NET 10 SDK, Node.js and Claude Code signed in.

```powershell
./scripts/build-windows.ps1 -Install
```

This builds the CLI and the app, installs it in `%LOCALAPPDATA%\Programs\QuickTranslator`, adds a Start menu shortcut and launches it. Like on the Mac, it runs `cli/dist/cli.js` from this repo (paths in `paths.json` next to the exe), so rebuild after moving the repo or changing Node.

## CLI

The app uses `quick-translate`, a small CLI in `cli/` that you can also run on its own:

```bash
cd cli && npm install && npm run build

node dist/cli.js "Nos vemos mañana a primera hora"
echo "See you tomorrow" | node dist/cli.js --to French --count 3
```

Options: `--provider claude-code|claude-api|openai|deepl` (keys in `QT_ANTHROPIC_API_KEY`, `QT_OPENAI_API_KEY` and `QT_DEEPL_AUTH_KEY`), `--api-model <id>` for the Claude API, `--openai-model <id>` for OpenAI (default `gpt-6-luna`), `--openai-base-url <url>` for an OpenAI-compatible server, `--mine <language>` (default Spanish) and `--target <language>` (default English) for the language pair, `--to <language>` to force one target, `--count <1-8>`, `--model <id>` (default `claude-haiku-5-5`), `--effort low|medium|high`, `--server`.

With `--server` it stays running, keeps Claude Code warm and answers one JSON request per line:

```
→ {"id":"1","text":"Nos vemos mañana","mine":"Spanish","target":"English"}
← {"id":"1","model":"claude-haiku-5-5","result":{"sourceLanguage":"Spanish","targetLanguage":"English","variants":[{"label":"Natural","text":"See you tomorrow"}]}}
```

## Development

```bash
./scripts/test.sh                  # CLI, Swift (on macOS) and .NET (when dotnet is installed) tests
./scripts/build-app.sh --install   # rebuild and relaunch the Mac app
./scripts/build-windows.ps1 -Install  # rebuild and relaunch the Windows app
```

- `cli/` — TypeScript CLI on the Claude Agent SDK.
- `app/Sources/QuickTranslatorCore/` — testable logic shared by the app.
- `app/Sources/QuickTranslator/` — the menu bar app.
- `windows/QuickTranslator.Core/` — testable logic of the Windows app; `windows/QuickTranslator/` — the tray app.

See [CLAUDE.md](CLAUDE.md) for architecture notes and contribution rules.

## License

[MIT](LICENSE)
