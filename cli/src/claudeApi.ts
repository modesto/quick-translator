import Anthropic from "@anthropic-ai/sdk";
import { betaZodOutputFormat } from "@anthropic-ai/sdk/helpers/beta/zod";
import { z } from "zod";
import { ProviderError, type TranslationProvider } from "./providers.js";
import { buildPrompt, SYSTEM_PROMPT, type RequestOptions, type TranslationResult } from "./translate.js";

export const DEFAULT_API_MODEL = "claude-haiku-5-5";

const TranslationSchema = z.object({
  sourceLanguage: z.string(),
  targetLanguage: z.string(),
  variants: z.array(z.object({ label: z.string(), text: z.string() })),
});

const MODELS_WITH_SERVER_FALLBACK = new Set(["claude-opus-5-5", "claude-sonnet-5-5", "claude-fable-5-2"]);

type ParseParams = Parameters<Anthropic["beta"]["messages"]["parse"]>[0];

export interface ParseClient {
  beta: { messages: { parse(params: ParseParams): PromiseLike<ParsedResponse> } };
}

interface ParsedResponse {
  stop_reason: string | null;
  parsed_output?: unknown;
}

export function requestParams(model: string, text: string, request: RequestOptions): ParseParams {
  const params: ParseParams = {
    model,
    max_tokens: 8000,
    system: SYSTEM_PROMPT,
    messages: [{ role: "user", content: buildPrompt(text, request) }],
    output_config: { effort: "low", format: betaZodOutputFormat(TranslationSchema) },
  };
  if (model.startsWith("claude-haiku-5")) {
    params.thinking = { type: "disabled" };
  }
  if (MODELS_WITH_SERVER_FALLBACK.has(model)) {
    params.betas = ["server-side-fallback-2026-07-01"];
    params.fallbacks = "default";
  }
  return params;
}

export function providerErrorFrom(error: unknown): ProviderError {
  if (error instanceof ProviderError) return error;
  if (error instanceof Anthropic.AuthenticationError || error instanceof Anthropic.PermissionDeniedError) {
    return new ProviderError("auth_failed", "The Claude API rejected the API key");
  }
  if (error instanceof Anthropic.RateLimitError) {
    return new ProviderError("rate_limited", "The Claude API rate limit was reached");
  }
  if (error instanceof Anthropic.APIConnectionError) {
    return new ProviderError("network", "Could not reach the Claude API");
  }
  if (error instanceof Anthropic.APIError) {
    return new ProviderError("provider_error", `Claude API error ${error.status}: ${error.message}`);
  }
  return new ProviderError("provider_error", error instanceof Error ? error.message : String(error));
}

export class ClaudeApiTranslator implements TranslationProvider {
  readonly id = "claude-api" as const;
  private readonly client: ParseClient | undefined;

  constructor(
    readonly model: string,
    apiKey: string | undefined,
    client?: ParseClient,
  ) {
    this.client = client ?? (apiKey ? new Anthropic({ apiKey }) : undefined);
  }

  async warmUp(): Promise<void> {
    if (!this.client) throw new ProviderError("missing_key", "No Claude API key configured");
  }

  async translate(text: string, request: RequestOptions): Promise<TranslationResult> {
    if (!this.client) throw new ProviderError("missing_key", "No Claude API key configured");
    let response: ParsedResponse;
    try {
      response = await this.client.beta.messages.parse(requestParams(this.model, text, request));
    } catch (error) {
      throw providerErrorFrom(error);
    }
    if (response.stop_reason === "refusal") {
      throw new ProviderError("refused", "Claude declined to translate this text");
    }
    const parsed = TranslationSchema.safeParse(response.parsed_output);
    if (!parsed.success) {
      throw new ProviderError("provider_error", `Claude returned no translation (stop reason: ${response.stop_reason})`);
    }
    return parsed.data;
  }

  async close(): Promise<void> {}
}
