# Quick Translator

macOS menu bar app (with a Windows tray port in `windows/`) that translates the selected text in any app and replaces it with the chosen translation. Two providers: Apple Translation (on-device, instant) and Claude (several variants, through the Claude Agent SDK and the user's Claude Code login, no API key).

## Layout

- `cli/` — `quick-translate`, TypeScript CLI with four providers behind `TranslationProvider` (`src/providers.ts`): Claude Code (`@anthropic-ai/claude-agent-sdk`), Claude API (`@anthropic-ai/sdk`, `src/claudeApi.ts`), OpenAI (Responses API over `fetch`, `src/openai.ts`) and DeepL (`fetch`, `src/deepl.ts`). Provider failures are `ProviderError`s with a code the app turns into Spanish.
  - `src/translate.ts` — prompt, JSON schema, `translate()` and `WarmTranslator` (keeps a pre-warmed Claude Code process via `startup()`).
  - `src/server.ts` — `--server` mode: newline-delimited JSON over stdin/stdout. `serve()` takes its translator, input and output so tests can inject fakes.
  - `src/options.ts` — argument parsing and defaults (provider `claude-code`, model `claude-haiku-5-5`, 4 variants, effort `low`).
- `app/` — Swift package, macOS 26+.
  - `Sources/QuickTranslatorCore/` — pure, testable logic: models, popup placement, server line protocol and request routing, choice keys, model names, language rules, settings, language pair, shortcut formatting/validation and `ShortcutManager` (register, fall back, persist) behind the `HotKeyRegistering` protocol.
  - `Sources/QuickTranslator/` — AppKit/SwiftUI glue: menu bar item, Settings window (General and Proveedor tabs), Keychain key storage, global hotkey (default ⌥⌘T, configurable in Settings), macOS Service, Accessibility selection reading, paste-based replacement, popup, Apple Translation, CLI server process.
- `windows/` — .NET 10 solution for Windows (`QuickTranslator.slnx`; its own `nuget.config` uses only nuget.org).
  - `QuickTranslator.Core/` — pure, testable logic ported from `QuickTranslatorCore`: models, server protocol and router, providers, settings (`ISettingsStore`, JSON file in `%APPDATA%\QuickTranslator`), language pair, selection text (plus Windows `HTML Format` fragments), shortcut (Win32 virtual keys and `MOD_` flags) and `ShortcutManager`, popup placement (y-down pixels), popup texts, `UIStrings` (`UIStrings.cs`) in the six languages.
  - `QuickTranslator.Core.Tests/` — xUnit tests.
  - `QuickTranslator/` — WPF glue (Fluent theme, `ThemeMode="System"`): tray icon (WinForms `NotifyIcon`), `RegisterHotKey` on a message-only window, Ctrl+C/Ctrl+V via `SendInput`, UI Automation for the selection bounds, popup, Settings window, Credential Manager, HKCU Run key, CLI server process.
- `scripts/build-app.sh` — builds the CLI and the app, writes `Info.plist` and signs the bundle; `--install` copies it to `~/Applications`, refreshes Services and launches it.
- `scripts/build-windows.ps1` — builds the CLI and the Windows app into `build\windows` and writes `paths.json`; `-Install` copies it to `%LOCALAPPDATA%\Programs\QuickTranslator`, adds a Start menu shortcut and launches it.
- `scripts/test.sh` — runs the CLI tests, the Swift tests on macOS and the .NET tests when `dotnet` is installed.

## Commands

```bash
./scripts/test.sh                  # all tests
(cd cli && npm test)               # CLI tests (builds first)
(cd app && swift test)             # app tests
./scripts/build-app.sh --install   # build, install and relaunch the app
(cd windows && dotnet test QuickTranslator.Core.Tests)   # Windows app tests
pwsh scripts/build-windows.ps1 -Install                  # build, install and relaunch the Windows app
```

## Rules

- Every new feature or bug fix ships with tests. Put the logic in `QuickTranslatorCore` (Swift), `QuickTranslator.Core` (C#) or in an exported, dependency-injected function (TypeScript) so it can be tested without UI, Accessibility or network, then cover it there.
- Run `./scripts/test.sh` before every commit; all tests must pass.
- Tests never call Claude or need Accessibility permission. Use fakes for the translator and injected `UserDefaults` for settings.
- Code, comments, commit messages and docs are in English. User-facing UI strings live only in `UIStrings` (`QuickTranslatorCore/Localization.swift`), in all six UI languages (es, en, fr, de, it, pt); never hard-code them in views or menus. Add every new string to all six.
- Tests never change `L10n.language`: it is global and tests run in parallel. Pass a `UILanguage` explicitly (`message(in:)`, `alert(for:language:)`, `Elapsed.format(_:in:)`…).

## Things to know

- The app only sees changes after `./scripts/build-app.sh --install`. It runs `cli/dist/cli.js` from this repo, so CLI changes need a rebuild, and the app must be relaunched to restart the server.
- `Info.plist` stores absolute paths to `node` and `cli/dist/cli.js` (`QTNodePath`, `QTCLIPath`). Moving the repo or changing the Node install needs a rebuild.
- The bundle is signed with the identity in `CODESIGN_IDENTITY` (ad-hoc when unset). Use an Apple Development certificate (free with a personal team: Xcode → Settings → Accounts → Manage Certificates); it needs the "Apple Worldwide Developer Relations Certification Authority" G3 intermediate in the keychain (`apple.com/certificateauthority/AppleWWDRCAG3.cer`), else `security find-identity -v -p codesigning` does not list it as valid. Its Team ID keeps the Accessibility permission and Keychain "Always Allow" across rebuilds. An ad-hoc signature makes macOS drop Accessibility on every build; a self-signed certificate keeps Accessibility but, having no Team ID, ties "Always Allow" to the binary's hash, so every rebuild prompts again for each key read. Switching certificates needs Accessibility granted again once. Personal team certificates expire after a year.
- Agent shells don't load `~/.zshrc`, where `CODESIGN_IDENTITY` is exported: pass it explicitly (`CODESIGN_IDENTITY="Apple Development: …" ./scripts/build-app.sh --install`) and check `codesign -dvv` shows the `TeamIdentifier`.
- Selection replacement pastes through the clipboard (simulated ⌘V) and restores it afterwards; it works in native and Electron apps.
- Reading the selection: in native apps, Accessibility only. Inside web content (an `AXWebArea` ancestor: Teams, Slack, browsers) it also copies with a simulated ⌘C, because web apps draw some emoji as images that Accessibility leaves out. `SelectionText.best` then prefers the copied HTML only when it has emoji markup (Teams `itemtype=".../Emoji" itemscope="😅"` elements, `<img alt="🚀">`), else the copied plain text, else the Accessibility text. Teams' plain text replaces its own emoji with their names ("Sweat grinning").
- One-off target: the globe menu in the popup sets a target for the current text only (`targetOverride`, sent to the server as `to`); it is never stored and resets on the next translation.
- Language pair: "mine" and "target". Text in "mine" goes to "target", anything else to "mine". The app detects the language for Apple Translation with `NLLanguageRecognizer`; for Claude it sends both languages by English name and lets Claude apply the rule.
- Server protocol: request `{"id","text","to"?,"mine"?,"target"?,"count"?,"provider"?}` (`mine` and `target` go together; `to` forces one target; `provider` defaults to `--provider`); responses `{"id","provider","model","result"}` or `{"id","provider","error","code"?}`; one `{"ready","provider","model"}` (or `ready:false` with the error) message at start. Only the default provider is warmed; the others are created on first use. The app ignores answers to cancelled or replaced requests.
- Apple Translation uses `TranslationSession(installedSource:target:)`, so it only works with downloaded languages and never shows system UI. When the language pair changes, `LanguageAvailability` is checked in both directions and `LanguagePackAdvice` decides whether to offer opening Language & Region (`x-apple.systempreferences:com.apple.Localization-Settings.extension`; there is no deep link to the Translation Languages sheet). It returns a single translation; it cannot produce variants.
- Never check which Apple Translation languages are downloaded with a standalone binary (e.g. a `swiftc` script run from the terminal): there `LanguageAvailability` reports every language as installed and translations succeed, while the app sees the real state. Check from inside the app, or ask the user.
- When Apple Translation fails because a language is missing, the popup shows a "Descargar idioma…" button that opens Language & Region (`AppleTranslatorError.offersLanguageDownload`).
- Provider keys live in the Keychain (`KeychainSecretStore`) and reach the server as `QT_ANTHROPIC_API_KEY` / `QT_OPENAI_API_KEY` / `QT_DEEPL_AUTH_KEY`. Only the active provider's key is read and passed, so a build signed without a Team ID prompts at most once. Settings only checks that keys exist (`hasSecret`), which never prompts. Never use `ANTHROPIC_API_KEY`: the Claude Code subprocess would switch from the user's login to API billing. `claudeCodeEnv` also strips the `QT_` keys from Claude Code's environment. Changing the provider, model or a key restarts the server.
- Claude API requests use effort `low`, thinking disabled on Haiku 5.5 (Sonnet/Opus 5.5 reject that), and server-side refusal fallbacks on the models that support them.
- OpenAI requests go to `/v1/responses` with a strict JSON schema, `store: false`, and reasoning effort `none` (Luna and Terra) or `low` (Sol and Astra reject `none`). A custom base URL (`--openai-base-url`, Settings "URL del API"; empty means OpenAI) switches to Chat Completions with `response_format` json_schema and no reasoning fields, because compatible servers (Ollama, OpenRouter, Groq…) support it more widely; there the key is optional and the model name is free text. The app keeps one model for OpenAI and another for the compatible server (`openAIModel` / `openAICompatibleModel`). `reasoning` is only sent to model families that accept it (GPT-5+, o-series); `none` only to Luna and Terra.
- DeepL picks the free or paid endpoint from the key (`:fx`), asks for formal and informal versions in parallel when the target supports formality, and detects the source itself: if the text is not in "mine", it translates again into "mine".
- The warm Claude Code process uses about 270 MB while idle.
- UI language: `UILanguage.forLanguage(languagePair.mine)`, English when "mine" has no translation. `L10n.language` is set at launch and when "mine" changes; the Settings view rebuilds with `.id(model.uiLanguage)` and the menus are rebuilt. Language names use the UI language: `Languages.displayName` (capitalized, for lists) and `Languages.name` (as written mid-sentence). The Services menu entry comes from `Info.plist` and stays in Spanish.
- "Open at login" (General tab) uses `SMAppService.mainApp` behind `LoginItemService`; `LaunchAtLogin` treats `requiresApproval` as on and Settings then offers to open Login Items.
- The app runs as an accessory (no Dock icon, no menu bar), so it installs a hidden main menu with an Edit menu (`EditMenu`): without it ⌘V/⌘C in text fields only beep. The Settings window switches the app to `.regular` while open so it comes to the front, and back to `.accessory` when closed.

## Windows app

- Same features as the Mac app except Apple Translation (Windows has no public on-device translation API) and the macOS Service. The popup shows only the configured provider; keys 1–9 pick a variant.
- Changes to shared behaviour (protocol, settings, providers, strings) usually belong in both `app/` and `windows/`. On Windows, strings live in `QuickTranslator.Core/UIStrings.cs`, in the same six languages.
- `paths.json` next to the exe holds `nodePath` and `cliPath`, like `QTNodePath` / `QTCLIPath`. The build script resolves Node with `realpath`, because fnm/nvm shims live in per-shell folders that disappear.
- Reading the selection: wait until the hotkey modifiers are released (a Ctrl+C sent while Alt is down arrives as Ctrl+Alt+C), snapshot the clipboard, send Ctrl+C, wait for `GetClipboardSequenceNumber` to change, read Unicode text and `HTML Format`, restore the clipboard. The anchor comes from the UI Automation `TextPattern` selection bounds, else the Win32 caret, else the cursor.
- The app is per-monitor DPI aware (`app.manifest`): screen coordinates are physical pixels and the popup is placed with `SetWindowPos`.
- "Translate selection" in the tray menu uses the last foreground window of another app (`ForegroundTracker`), because clicking the tray brings the taskbar to the front.
- The CLI server runs in a job object with kill-on-close, so it and its Claude Code subprocess die with the app even if it crashes.
- Windows blocks `SendInput` into elevated apps from a non-elevated process.
- The WPF Fluent theme is experimental (`WPF0001` is suppressed). Use its brushes (`TextFillColorPrimaryBrush`…) through `DynamicResource`, so a missing key never crashes.
