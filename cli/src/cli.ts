#!/usr/bin/env node
import { parseOptions } from "./options.js";
import { API_KEY_ENV } from "./providers.js";
import { defaultProviderFactory, runServer } from "./server.js";
import { translate } from "./translate.js";

const USAGE = `Usage: quick-translate [options] [text]
       quick-translate --server [options]

Reads the text from the argument or, if absent, from stdin.
Prints a JSON object with several translation variants.

With --server, stays running and keeps the default provider warm. Reads one
JSON request per line on stdin ({"id": "1", "text": "...", "to"?: "French",
"mine"?: "Spanish", "target"?: "English", "count"?: 4, "provider"?: "deepl"})
and writes one JSON response per line on stdout ({"id": "1", "provider": ...,
"model": ..., "result": {...}} or {"id": "1", "error": "...", "code"?: ...}).

Providers:
  claude-code   Claude through the Claude Code login (default)
  claude-api    Claude API; needs ${API_KEY_ENV["claude-api"]}
  deepl         DeepL; needs ${API_KEY_ENV.deepl} (keys ending in :fx use the free API)

Options:
  -t, --to <language>    Always translate into this language, ignoring --mine/--target
      --mine <language>    Your language (default: Spanish)
      --target <language>  Language for text written in yours (default: English);
                           text in any other language is translated into yours
  -n, --count <n>        Number of variants (default: 4)
  -p, --provider <id>    claude-code | claude-api | deepl (default: claude-code)
  -m, --model <model>    Claude Code model (default: claude-haiku-5-5)
      --api-model <model>  Claude API model (default: claude-haiku-5-5)
  -e, --effort <level>   low | medium | high (default: low)
  -s, --server           Run as a long-lived translation server
  -h, --help             Show this help`;

async function readStdin(): Promise<string> {
  if (process.stdin.isTTY) return "";
  const chunks: Buffer[] = [];
  for await (const chunk of process.stdin) chunks.push(chunk as Buffer);
  return Buffer.concat(chunks).toString("utf8");
}

async function main(): Promise<void> {
  const { text: argText, options, help, server, provider, apiModel } = parseOptions(process.argv.slice(2));
  if (help) {
    console.log(USAGE);
    return;
  }
  if (server) {
    await runServer(
      { model: options.model, effort: options.effort },
      { defaultProvider: provider, defaultCount: options.count, defaultLanguagePair: options.languagePair, apiModel },
    );
    return;
  }

  const text = (argText ?? (await readStdin())).trim();
  if (!text) {
    console.error(USAGE);
    process.exit(2);
  }

  const result =
    provider === "claude-code"
      ? await translate(text, options)
      : await defaultProviderFactory(options, apiModel, process.env)(provider).translate(text, options);
  process.stdout.write(JSON.stringify(result, null, 2) + "\n");
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(JSON.stringify({ error: message }) + "\n");
  process.exit(1);
});
