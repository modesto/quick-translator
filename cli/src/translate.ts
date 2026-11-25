import { query, startup, type Options, type Query, type WarmQuery } from "@anthropic-ai/claude-agent-sdk";
import { API_KEY_ENV, type TranslationProvider } from "./providers.js";

export interface EngineOptions {
  model: string;
  effort: "low" | "medium" | "high";
}

export interface LanguagePair {
  mine: string;
  target: string;
}

export const DEFAULT_LANGUAGE_PAIR: LanguagePair = { mine: "Spanish", target: "English" };

export interface RequestOptions {
  targetLanguage?: string;
  languagePair?: LanguagePair;
  count: number;
}

export type TranslateOptions = EngineOptions & RequestOptions;

export interface TranslationVariant {
  label: string;
  text: string;
}

export interface TranslationResult {
  sourceLanguage: string;
  targetLanguage: string;
  variants: TranslationVariant[];
}

export const RESULT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["sourceLanguage", "targetLanguage", "variants"],
  properties: {
    sourceLanguage: { type: "string" },
    targetLanguage: { type: "string" },
    variants: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["label", "text"],
        properties: {
          label: { type: "string" },
          text: { type: "string" },
        },
      },
    },
  },
};

export const SYSTEM_PROMPT = `You are a translation engine used from a text-replacement popup. You never chat, ask questions or use tools other than returning the structured result.

Given a text, return one translation into the target language for each style listed in the request, in that order:
- Literal: faithful to the wording and structure of the original.
- Natural: how a native speaker would say it.
- Formal: a polite, professional register.
- Conciso: the shortest translation that keeps the meaning.
If the request asks for more variants than the listed styles, add other distinct styles after them. Make every variant read differently whenever the text allows it.

Rules:
- Each variant must be a drop-in replacement for the original: keep line breaks, surrounding whitespace, punctuation style, placeholders, URLs, code, emoji and Markdown exactly as in the source.
- Never add quotes, notes, explanations or transliterations to the variant text.
- "label" is the style's name exactly as listed ("Literal", "Natural", "Formal", "Conciso"); for any extra style, a short Spanish name of one or two words.
- "sourceLanguage" and "targetLanguage" are English names of the languages, e.g. "Spanish", "English".`;

export function claudeCodeEnv(env: NodeJS.ProcessEnv): NodeJS.ProcessEnv {
  const result: NodeJS.ProcessEnv = { ...env, CLAUDE_AGENT_SDK_CLIENT_APP: "quick-translate/0.1.0" };
  for (const name of Object.values(API_KEY_ENV)) delete result[name];
  return result;
}

function queryOptions(engine: EngineOptions): Options {
  return {
    model: engine.model,
    effort: engine.effort,
    systemPrompt: SYSTEM_PROMPT,
    tools: [],
    settingSources: [],
    persistSession: false,
    maxTurns: 3,
    outputFormat: { type: "json_schema", schema: RESULT_SCHEMA },
    env: claudeCodeEnv(process.env),
  };
}

export const VARIANT_STYLES = ["Literal", "Natural", "Formal", "Conciso"] as const;

export function stylesFor(count: number): string[] {
  return VARIANT_STYLES.slice(0, count);
}

export function buildPrompt(text: string, request: RequestOptions): string {
  const pair = request.languagePair ?? DEFAULT_LANGUAGE_PAIR;
  const target = request.targetLanguage
    ? `Target language: ${request.targetLanguage}.`
    : `Target language: ${pair.target} if the text is in ${pair.mine}; otherwise ${pair.mine}.`;
  return `${target}
Number of variants: ${request.count}.
Styles: ${stylesFor(request.count).join(", ")}.

<text>
${text}
</text>`;
}

export function isTranslationResult(value: unknown): value is TranslationResult {
  if (typeof value !== "object" || value === null) return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.sourceLanguage === "string" &&
    typeof candidate.targetLanguage === "string" &&
    Array.isArray(candidate.variants) &&
    candidate.variants.every(
      (variant) =>
        typeof variant === "object" &&
        variant !== null &&
        typeof (variant as Record<string, unknown>).label === "string" &&
        typeof (variant as Record<string, unknown>).text === "string",
    )
  );
}

async function collectResult(stream: Query): Promise<TranslationResult> {
  for await (const message of stream) {
    if (message.type !== "result") continue;
    if (message.subtype !== "success") {
      throw new Error(`Translation failed: ${message.subtype}`);
    }
    if (!isTranslationResult(message.structured_output)) {
      throw new Error("Translation returned an unexpected shape");
    }
    return message.structured_output;
  }
  throw new Error("Translation ended without a result");
}

export async function translate(text: string, options: TranslateOptions): Promise<TranslationResult> {
  return collectResult(query({ prompt: buildPrompt(text, options), options: queryOptions(options) }));
}

export class WarmTranslator implements TranslationProvider {
  readonly id = "claude-code" as const;

  get model(): string {
    return this.engine.model;
  }

  private spare: Promise<WarmQuery> | undefined;

  constructor(private readonly engine: EngineOptions) {}

  warmUp(): Promise<WarmQuery> {
    if (!this.spare) {
      const spare = startup({ options: queryOptions(this.engine) });
      spare.catch(() => {
        if (this.spare === spare) this.spare = undefined;
      });
      this.spare = spare;
    }
    return this.spare;
  }

  async translate(text: string, request: RequestOptions): Promise<TranslationResult> {
    const warm = await this.takeSpare();
    this.warmUp();
    return collectResult(warm.query(buildPrompt(text, request)));
  }

  async close(): Promise<void> {
    const spare = this.spare;
    this.spare = undefined;
    (await spare?.catch(() => undefined))?.close();
  }

  private async takeSpare(): Promise<WarmQuery> {
    try {
      return await this.claim();
    } catch {
      return this.claim();
    }
  }

  private async claim(): Promise<WarmQuery> {
    const spare = this.warmUp();
    this.spare = undefined;
    return spare;
  }
}
