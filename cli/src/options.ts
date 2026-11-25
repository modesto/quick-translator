import { parseArgs } from "node:util";
import { DEFAULT_API_MODEL } from "./claudeApi.js";
import { DEFAULT_OPENAI_MODEL } from "./openai.js";
import { DEFAULT_PROVIDER, isProviderId, PROVIDER_IDS, type ApiModels, type ProviderId } from "./providers.js";
import { DEFAULT_LANGUAGE_PAIR, type TranslateOptions } from "./translate.js";

export const DEFAULT_MODEL = "claude-haiku-5-5";
export const DEFAULT_COUNT = 4;
export const MAX_COUNT = 8;

export interface CliOptions {
  text: string | undefined;
  options: TranslateOptions;
  help: boolean;
  server: boolean;
  provider: ProviderId;
  models: ApiModels;
}

export function isValidCount(count: unknown): count is number {
  return typeof count === "number" && Number.isInteger(count) && count >= 1 && count <= MAX_COUNT;
}

export function parseOptions(args: string[]): CliOptions {
  const { values, positionals } = parseArgs({
    args,
    allowPositionals: true,
    options: {
      to: { type: "string", short: "t" },
      mine: { type: "string" },
      target: { type: "string" },
      count: { type: "string", short: "n" },
      model: { type: "string", short: "m" },
      effort: { type: "string", short: "e" },
      help: { type: "boolean", short: "h" },
      server: { type: "boolean", short: "s" },
      provider: { type: "string", short: "p" },
      "api-model": { type: "string" },
      "openai-model": { type: "string" },
      "openai-base-url": { type: "string" },
    },
  });

  const effort = values.effort ?? "low";
  if (!["low", "medium", "high"].includes(effort)) {
    throw new Error(`Invalid effort: ${effort}`);
  }

  const count = values.count === undefined ? DEFAULT_COUNT : Number(values.count);
  if (!isValidCount(count)) {
    throw new Error(`--count must be an integer between 1 and ${MAX_COUNT}`);
  }

  const provider = values.provider ?? DEFAULT_PROVIDER;
  if (!isProviderId(provider)) {
    throw new Error(`--provider must be one of ${PROVIDER_IDS.join(", ")}`);
  }

  const languagePair = {
    mine: values.mine ?? DEFAULT_LANGUAGE_PAIR.mine,
    target: values.target ?? DEFAULT_LANGUAGE_PAIR.target,
  };
  if (languagePair.mine.toLowerCase() === languagePair.target.toLowerCase()) {
    throw new Error("--mine and --target must be different languages");
  }

  return {
    text: positionals.length > 0 ? positionals.join(" ") : undefined,
    help: values.help ?? false,
    server: values.server ?? false,
    provider,
    models: {
      claudeApi: values["api-model"] ?? DEFAULT_API_MODEL,
      openai: values["openai-model"] ?? DEFAULT_OPENAI_MODEL,
      openaiBaseURL: values["openai-base-url"]?.trim() || undefined,
    },
    options: {
      targetLanguage: values.to,
      languagePair,
      count,
      model: values.model ?? DEFAULT_MODEL,
      effort: effort as TranslateOptions["effort"],
    },
  };
}
