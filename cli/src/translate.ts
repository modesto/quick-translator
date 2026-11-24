import { query } from "@anthropic-ai/claude-agent-sdk";

export interface TranslateOptions {
  targetLanguage?: string;
  count: number;
  model: string;
  effort: "low" | "medium" | "high";
}

export interface TranslationVariant {
  label: string;
  text: string;
}

export interface TranslationResult {
  sourceLanguage: string;
  targetLanguage: string;
  variants: TranslationVariant[];
}

const RESULT_SCHEMA = {
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

const SYSTEM_PROMPT = `You are a translation engine used from a text-replacement popup. You never chat, ask questions or use tools other than returning the structured result.

Given a text, return several distinct translations of it into the target language, each with a different register or nuance, for example: faithful/literal, natural, formal, casual, concise. Pick the styles that make the most sense for this text, and make sure every variant reads differently; do not return near-duplicates.

Rules:
- Each variant must be a drop-in replacement for the original: keep line breaks, surrounding whitespace, punctuation style, placeholders, URLs, code, emoji and Markdown exactly as in the source.
- Never add quotes, notes, explanations or transliterations to the variant text.
- "label" is a short name for the style (one or two words) written in Spanish, e.g. "Literal", "Natural", "Formal", "Informal", "Conciso".
- "sourceLanguage" and "targetLanguage" are English names of the languages, e.g. "Spanish", "English".`;

function buildPrompt(text: string, options: TranslateOptions): string {
  const target = options.targetLanguage
    ? `Target language: ${options.targetLanguage}.`
    : "Target language: English if the text is in Spanish; otherwise Spanish.";
  return `${target}
Number of variants: ${options.count}.

<text>
${text}
</text>`;
}

function isTranslationResult(value: unknown): value is TranslationResult {
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

export async function translate(text: string, options: TranslateOptions): Promise<TranslationResult> {
  const stream = query({
    prompt: buildPrompt(text, options),
    options: {
      model: options.model,
      effort: options.effort,
      systemPrompt: SYSTEM_PROMPT,
      tools: [],
      settingSources: [],
      persistSession: false,
      maxTurns: 3,
      outputFormat: { type: "json_schema", schema: RESULT_SCHEMA },
      env: { ...process.env, CLAUDE_AGENT_SDK_CLIENT_APP: "quick-translate/0.1.0" },
    },
  });

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
