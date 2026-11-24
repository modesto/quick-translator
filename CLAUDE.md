# Quick Translator

macOS menu bar app that translates the selected text in any app and replaces it with the chosen translation. Two providers: Apple Translation (on-device, instant) and Claude (several variants, through the Claude Agent SDK and the user's Claude Code login, no API key).

## Layout

- `cli/` — `quick-translate`, TypeScript CLI on `@anthropic-ai/claude-agent-sdk`.
  - `src/translate.ts` — prompt, JSON schema, `translate()` and `WarmTranslator` (keeps a pre-warmed Claude Code process via `startup()`).
  - `src/server.ts` — `--server` mode: newline-delimited JSON over stdin/stdout. `serve()` takes its translator, input and output so tests can inject fakes.
  - `src/options.ts` — argument parsing and defaults (model `claude-haiku-5-5`, 4 variants, effort `low`).
- `app/` — Swift package, macOS 26+.
  - `Sources/QuickTranslatorCore/` — pure, testable logic: models, popup placement, server line protocol and request routing, choice keys, model names, language rules, settings, language pair, shortcut formatting/validation and `ShortcutManager` (register, fall back, persist) behind the `HotKeyRegistering` protocol.
  - `Sources/QuickTranslator/` — AppKit/SwiftUI glue: menu bar item, global hotkey (default ⌥⌘T, configurable from the menu), macOS Service, Accessibility selection reading, paste-based replacement, popup, Apple Translation, CLI server process.
- `scripts/build-app.sh` — builds the CLI and the app, writes `Info.plist` and signs the bundle; `--install` copies it to `~/Applications`, refreshes Services and launches it.
- `scripts/test.sh` — runs both test suites.

## Commands

```bash
./scripts/test.sh                  # all tests
(cd cli && npm test)               # CLI tests (builds first)
(cd app && swift test)             # app tests
./scripts/build-app.sh --install   # build, install and relaunch the app
```

## Rules

- Every new feature or bug fix ships with tests. Put the logic in `QuickTranslatorCore` (Swift) or in an exported, dependency-injected function (TypeScript) so it can be tested without UI, Accessibility or network, then cover it there.
- Run `./scripts/test.sh` before every commit; all tests must pass.
- Tests never call Claude or need Accessibility permission. Use fakes for the translator and injected `UserDefaults` for settings.
- Code, comments, commit messages and docs are in English. User-facing UI strings are in Spanish.

## Things to know

- The app only sees changes after `./scripts/build-app.sh --install`. It runs `cli/dist/cli.js` from this repo, so CLI changes need a rebuild, and the app must be relaunched to restart the server.
- `Info.plist` stores absolute paths to `node` and `cli/dist/cli.js` (`QTNodePath`, `QTCLIPath`). Moving the repo or changing the Node install needs a rebuild.
- The bundle is signed with the identity in `CODESIGN_IDENTITY` (ad-hoc when unset). An ad-hoc signature changes on every build and makes macOS drop the Accessibility permission, so set it to a stable code signing certificate.
- Selection replacement pastes through the clipboard (simulated ⌘V) and restores it afterwards; it works in native and Electron apps.
- Reading the selection: in native apps, Accessibility only. Inside web content (an `AXWebArea` ancestor: Teams, Slack, browsers) it also copies with a simulated ⌘C, because web apps draw some emoji as images that Accessibility leaves out. `SelectionText.best` then prefers the copied HTML only when it has emoji markup (Teams `itemtype=".../Emoji" itemscope="😅"` elements, `<img alt="🚀">`), else the copied plain text, else the Accessibility text. Teams' plain text replaces its own emoji with their names ("Sweat grinning").
- One-off target: the globe menu in the popup sets a target for the current text only (`targetOverride`, sent to the server as `to`); it is never stored and resets on the next translation.
- Language pair: "mine" and "target". Text in "mine" goes to "target", anything else to "mine". The app detects the language for Apple Translation with `NLLanguageRecognizer`; for Claude it sends both languages by English name and lets Claude apply the rule.
- Server protocol: request `{"id","text","to"?,"mine"?,"target"?,"count"?}` (`mine` and `target` go together; `to` forces one target); responses `{"id","model","result"}` or `{"id","error"}`; one `{"ready","model"}` message at start. The app ignores answers to cancelled or replaced requests.
- Apple Translation uses `TranslationSession(installedSource:target:)`, so it only works with downloaded languages and never shows system UI. When the language pair changes, `LanguageAvailability` is checked in both directions and `LanguagePackAdvice` decides whether to offer opening Language & Region (`x-apple.systempreferences:com.apple.Localization-Settings.extension`; there is no deep link to the Translation Languages sheet). It returns a single translation; it cannot produce variants.
- Never check which Apple Translation languages are downloaded with a standalone binary (e.g. a `swiftc` script run from the terminal): there `LanguageAvailability` reports every language as installed and translations succeed, while the app sees the real state. Check from inside the app, or ask the user.
- When Apple Translation fails because a language is missing, the popup shows a "Descargar idioma…" button that opens Language & Region (`AppleTranslatorError.offersLanguageDownload`).
- The warm Claude Code process uses about 270 MB while idle.
