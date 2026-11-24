#!/usr/bin/env node
import { parseArgs } from "node:util";
import { runServer } from "./server.js";
import { translate, type TranslateOptions } from "./translate.js";

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

function parseOptions(): { text: string | undefined; options: TranslateOptions; help: boolean; server: boolean } {
  const { values, positionals } = parseArgs({
    allowPositionals: true,
    options: {
      to: { type: "string", short: "t" },
      count: { type: "string", short: "n" },
      model: { type: "string", short: "m" },
      effort: { type: "string", short: "e" },
      help: { type: "boolean", short: "h" },
      server: { type: "boolean", short: "s" },
    },
  });

  const effort = values.effort ?? "low";
  if (!["low", "medium", "high"].includes(effort)) {
    throw new Error(`Invalid effort: ${effort}`);
  }

  const count = values.count ? Number.parseInt(values.count, 10) : 4;
  if (!Number.isInteger(count) || count < 1 || count > 8) {
    throw new Error("--count must be an integer between 1 and 8");
  }

  return {
    text: positionals.length > 0 ? positionals.join(" ") : undefined,
    help: values.help ?? false,
    server: values.server ?? false,
    options: {
      targetLanguage: values.to,
      count,
      model: values.model ?? "claude-haiku-5-5",
      effort: effort as TranslateOptions["effort"],
    },
  };
}

async function main(): Promise<void> {
  const { text: argText, options, help, server } = parseOptions();
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
