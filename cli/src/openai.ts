import type { Fetch } from "./deepl.js";
import { ProviderError, type TranslationProvider } from "./providers.js";
import { buildPrompt, isTranslationResult, RESULT_SCHEMA, SYSTEM_PROMPT, type RequestOptions, type TranslationResult } from "./translate.js";

export const DEFAULT_OPENAI_MODEL = "gpt-6-luna";
export const DEFAULT_OPENAI_BASE_URL = "https://api.openai.com/v1";

export type OpenAIApi = "responses" | "chat";

export interface OpenAIEndpoint {
  url: string;
  api: OpenAIApi;
  official: boolean;
}

/** OpenAI itself gets the Responses API; compatible servers (Ollama, OpenRouter, Groq…) only reliably speak Chat Completions. */
export function openAIEndpoint(baseURL: string | undefined): OpenAIEndpoint {
  const trimmed = (baseURL ?? "").trim().replace(/\/+$/, "").replace(/\/(responses|chat\/completions)$/, "");
  let base = trimmed || DEFAULT_OPENAI_BASE_URL;
  let parsed: URL;
  try {
    parsed = new URL(base);
  } catch {
    throw new ProviderError("provider_error", `Invalid OpenAI base URL: ${base}`);
  }
  if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
    throw new ProviderError("provider_error", `Invalid OpenAI base URL: ${base}`);
  }
  const official = parsed.hostname === "api.openai.com";
  if (official && parsed.pathname === "/") base = DEFAULT_OPENAI_BASE_URL;
  return official ? { url: `${base}/responses`, api: "responses", official } : { url: `${base}/chat/completions`, api: "chat", official };
}

const MODELS_WITH_NO_REASONING = /^gpt-6(\.\d+)?-(luna|terra)/;
const REASONING_MODELS = /^(gpt-[5-9]|o\d)/;

export function reasoningEffort(model: string): "none" | "low" | undefined {
  if (MODELS_WITH_NO_REASONING.test(model)) return "none";
  if (REASONING_MODELS.test(model)) return "low";
  return undefined;
}

export function openAIRequestBody(model: string, text: string, request: RequestOptions): Record<string, unknown> {
  const effort = reasoningEffort(model);
  return {
    model,
    instructions: SYSTEM_PROMPT,
    input: buildPrompt(text, request),
    ...(effort ? { reasoning: { effort } } : {}),
    store: false,
    text: { format: { type: "json_schema", name: "translation", schema: RESULT_SCHEMA, strict: true } },
  };
}

export function chatRequestBody(model: string, text: string, request: RequestOptions): Record<string, unknown> {
  return {
    model,
    messages: [
      { role: "system", content: SYSTEM_PROMPT },
      { role: "user", content: buildPrompt(text, request) },
    ],
    response_format: { type: "json_schema", json_schema: { name: "translation", schema: RESULT_SCHEMA, strict: true } },
  };
}

export function openAIErrorFromResponse(status: number, body: string): ProviderError {
  if (status === 401 || status === 403) return new ProviderError("auth_failed", "OpenAI rejected the API key");
  if (status === 429 && /insufficient_quota/.test(body)) return new ProviderError("quota_exceeded", "The OpenAI quota is used up");
  if (status === 429) return new ProviderError("rate_limited", "The OpenAI rate limit was reached");
  return new ProviderError("provider_error", `OpenAI error ${status}: ${body}`);
}

interface ResponseContent {
  type?: string;
  text?: string;
  refusal?: string;
}

interface ResponseBody {
  status?: string;
  incomplete_details?: { reason?: string } | null;
  output?: { type?: string; content?: ResponseContent[] }[];
}

interface ChatBody {
  choices?: { finish_reason?: string; message?: { content?: string | null; refusal?: string | null } }[];
}

export function resultFromChat(body: ChatBody): TranslationResult {
  const choice = body.choices?.[0];
  if (choice?.message?.refusal) throw new ProviderError("refused", "The model declined to translate this text");
  const content = choice?.message?.content;
  if (typeof content !== "string" || choice?.finish_reason === "length") {
    throw new ProviderError("provider_error", `The model returned no translation (${choice?.finish_reason ?? "no choices"})`);
  }
  return parseResult(content.replace(/^```(?:json)?\s*|\s*```$/g, ""));
}

function parseResult(text: string): TranslationResult {
  let parsed: unknown;
  try {
    parsed = JSON.parse(text);
  } catch {
    throw new ProviderError("provider_error", "OpenAI returned invalid JSON");
  }
  if (!isTranslationResult(parsed)) throw new ProviderError("provider_error", "OpenAI returned an unexpected result");
  return parsed;
}

export function resultFromResponse(body: ResponseBody): TranslationResult {
  const contents = (body.output ?? []).filter((item) => item.type === "message").flatMap((item) => item.content ?? []);
  if (contents.some((content) => content.type === "refusal")) {
    throw new ProviderError("refused", "OpenAI declined to translate this text");
  }
  const text = contents.find((content) => content.type === "output_text")?.text;
  if (body.status !== "completed" || text === undefined) {
    const reason = body.incomplete_details?.reason ?? body.status ?? "no output";
    throw new ProviderError("provider_error", `OpenAI returned no translation (${reason})`);
  }
  return parseResult(text);
}

export class OpenAITranslator implements TranslationProvider {
  readonly id = "openai" as const;

  private readonly baseURL: string | undefined;
  private readonly fetchImpl: Fetch;

  constructor(
    readonly model: string,
    private readonly apiKey: string | undefined,
    options: { baseURL?: string; fetch?: Fetch } = {},
  ) {
    this.baseURL = options.baseURL;
    this.fetchImpl = options.fetch ?? (fetch as unknown as Fetch);
  }

  async warmUp(): Promise<void> {
    this.checkKey(openAIEndpoint(this.baseURL));
  }

  async translate(text: string, request: RequestOptions): Promise<TranslationResult> {
    const endpoint = openAIEndpoint(this.baseURL);
    this.checkKey(endpoint);
    const headers: Record<string, string> = { "Content-Type": "application/json" };
    if (this.apiKey) headers.Authorization = `Bearer ${this.apiKey}`;
    const body = endpoint.api === "responses" ? openAIRequestBody(this.model, text, request) : chatRequestBody(this.model, text, request);
    let response: Awaited<ReturnType<Fetch>>;
    try {
      response = await this.fetchImpl(endpoint.url, { method: "POST", headers, body: JSON.stringify(body) });
    } catch {
      throw new ProviderError("network", `Could not reach ${endpoint.url}`);
    }
    if (!response.ok) throw openAIErrorFromResponse(response.status, await response.text().catch(() => ""));
    let json: unknown;
    try {
      json = await response.json();
    } catch {
      throw new ProviderError("provider_error", `${endpoint.url} did not return JSON`);
    }
    return endpoint.api === "responses" ? resultFromResponse(json as ResponseBody) : resultFromChat(json as ChatBody);
  }

  private checkKey(endpoint: OpenAIEndpoint): void {
    if (!this.apiKey && endpoint.official) throw new ProviderError("missing_key", "No OpenAI API key configured");
  }

  async close(): Promise<void> {}
}
