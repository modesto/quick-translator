#!/usr/bin/env node
import { parseOptions } from "./options.js";
import { runServer } from "./server.js";
import { translate } from "./translate.js";

const USAGE = `Usage: quick-translate [options] [text]
       quick-translate --server [options]

Reads the text from the argument or, if absent, from stdin.
Prints a JSON object with several translation variants.

With --server, stays running and keeps Claude Code warm. Reads one JSON
request per line on stdin ({"id": "1", "text": "...", "to"?: "French",
"count"?: 4}) and writes one JSON response per line on stdout
({"id": "1", "result": {...}} or {"id": "1", "error": "..."}).

Options:
  -t, --to <language>    Target language (default: English if the text is Spanish, otherwise Spanish)
  -n, --count <n>        Number of variants (default: 4)
  -m, --model <model>    Claude model (default: claude-haiku-5-5)
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
  const { text: argText, options, help, server } = parseOptions(process.argv.slice(2));
  if (help) {
    console.log(USAGE);
    return;
  }
  if (server) {
    await runServer({ model: options.model, effort: options.effort }, options.count);
    return;
  }

  const text = (argText ?? (await readStdin())).trim();
  if (!text) {
    console.error(USAGE);
    process.exit(2);
  }

  const result = await translate(text, options);
  process.stdout.write(JSON.stringify(result, null, 2) + "\n");
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  process.stderr.write(JSON.stringify({ error: message }) + "\n");
  process.exit(1);
});
