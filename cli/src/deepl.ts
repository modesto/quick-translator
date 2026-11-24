import { ProviderError, type TranslationProvider } from "./providers.js";
import { DEFAULT_LANGUAGE_PAIR, type RequestOptions, type TranslationResult, type TranslationVariant } from "./translate.js";

const LANGUAGES: Record<string, { source: string; target: string }> = {
  spanish: { source: "ES", target: "ES" },
  english: { source: "EN", target: "EN-US" },
  french: { source: "FR", target: "FR" },
  german: { source: "DE", target: "DE" },
  italian: { source: "IT", target: "IT" },
  portuguese: { source: "PT", target: "PT-PT" },
  dutch: { source: "NL", target: "NL" },
  polish: { source: "PL", target: "PL" },
  russian: { source: "RU", target: "RU" },
  ukrainian: { source: "UK", target: "UK" },
  turkish: { source: "TR", target: "TR" },
  arabic: { source: "AR", target: "AR" },
  hindi: { source: "HI", target: "HI" },
  indonesian: { source: "ID", target: "ID" },
  japanese: { source: "JA", target: "JA" },
  korean: { source: "KO", target: "KO" },
  thai: { source: "TH", target: "TH" },
  vietnamese: { source: "VI", target: "VI" },
  chinese: { source: "ZH", target: "ZH-HANS" },
};

const FORMALITY_TARGETS = new Set(["DE", "FR", "IT", "ES", "NL", "PL", "PT-PT", "PT-BR", "JA", "RU"]);

export function deeplLanguage(name: string): { source: string; target: string } {
  const language = LANGUAGES[name.trim().toLowerCase()];
  if (!language) throw new ProviderError("unsupported_language", `DeepL does not support ${name}`);
  return language;
}

export function englishName(deeplCode: string): string {
  const base = deeplCode.toUpperCase().split("-")[0];
  const entry = Object.entries(LANGUAGES).find(([, codes]) => codes.source === base);
  return entry ? entry[0].charAt(0).toUpperCase() + entry[0].slice(1) : deeplCode;
}

export function supportsFormality(targetCode: string): boolean {
  return FORMALITY_TARGETS.has(targetCode.toUpperCase());
}

export function deeplEndpoint(authKey: string): string {
  const host = authKey.trim().endsWith(":fx") ? "https://api-free.deepl.com" : "https://api.deepl.com";
  return `${host}/v2/translate`;
}

type Formality = "prefer_more" | "prefer_less";

interface DeepLTranslation {
  text: string;
  detectedSource: string;
}

export type Fetch = (url: string, init: { method: string; headers: Record<string, string>; body: string }) => Promise<{
  ok: boolean;
  status: number;
  json(): Promise<unknown>;
  text(): Promise<string>;
}>;

export function errorFromResponse(status: number, body: string): ProviderError {
  if (status === 403 || status === 401) return new ProviderError("auth_failed", "DeepL rejected the authentication key");
  if (status === 456) return new ProviderError("quota_exceeded", "The DeepL character quota is used up");
  if (status === 429) return new ProviderError("rate_limited", "Too many requests to DeepL");
  if (status === 400 && /lang/i.test(body)) return new ProviderError("unsupported_language", `DeepL does not support this language: ${body}`);
  return new ProviderError("provider_error", `DeepL error ${status}: ${body}`);
}

export class DeepLTranslator implements TranslationProvider {
  readonly id = "deepl" as const;
  readonly model = "deepl";

  constructor(
    private readonly authKey: string | undefined,
    private readonly fetchImpl: Fetch = fetch as unknown as Fetch,
  ) {}

  async warmUp(): Promise<void> {
    if (!this.authKey) throw new ProviderError("missing_key", "No DeepL authentication key configured");
  }

  async translate(text: string, request: RequestOptions): Promise<TranslationResult> {
    if (!this.authKey) throw new ProviderError("missing_key", "No DeepL authentication key configured");
    const pair = request.languagePair ?? DEFAULT_LANGUAGE_PAIR;
    const forced = request.targetLanguage;
    const firstTarget = deeplLanguage(forced ?? pair.target).target;

    let attempt = await this.translateAllTones(text, firstTarget);
    let target = firstTarget;
    const mine = deeplLanguage(pair.mine);
    if (!forced && attempt.detectedSource !== mine.source) {
      target = mine.target;
      attempt = await this.translateAllTones(text, target);
    }

    return {
      sourceLanguage: englishName(attempt.detectedSource),
      targetLanguage: englishName(target),
      variants: attempt.variants,
    };
  }

  async close(): Promise<void> {}

  private async translateAllTones(text: string, target: string): Promise<{ detectedSource: string; variants: TranslationVariant[] }> {
    if (!supportsFormality(target)) {
      const single = await this.request(text, target);
      return { detectedSource: single.detectedSource, variants: [{ label: "DeepL", text: single.text }] };
    }
    const [formal, informal] = await Promise.all([this.request(text, target, "prefer_more"), this.request(text, target, "prefer_less")]);
    const variants =
      formal.text === informal.text
        ? [{ label: "DeepL", text: formal.text }]
        : [
            { label: "Formal", text: formal.text },
            { label: "Informal", text: informal.text },
          ];
    return { detectedSource: formal.detectedSource, variants };
  }

  private async request(text: string, target: string, formality?: Formality): Promise<DeepLTranslation> {
    const body: Record<string, unknown> = { text: [text], target_lang: target, preserve_formatting: true };
    if (formality) body.formality = formality;

    let response: Awaited<ReturnType<Fetch>>;
    try {
      response = await this.fetchImpl(deeplEndpoint(this.authKey!), {
        method: "POST",
        headers: { Authorization: `DeepL-Auth-Key ${this.authKey!.trim()}`, "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
    } catch (error) {
      throw new ProviderError("network", `Could not reach DeepL: ${error instanceof Error ? error.message : String(error)}`);
    }
    if (!response.ok) throw errorFromResponse(response.status, await response.text());

    const payload = (await response.json()) as { translations?: Array<{ text?: unknown; detected_source_language?: unknown }> };
    const translation = payload.translations?.[0];
    if (typeof translation?.text !== "string" || typeof translation.detected_source_language !== "string") {
      throw new ProviderError("provider_error", "DeepL returned an unexpected response");
    }
    return { text: translation.text, detectedSource: translation.detected_source_language.toUpperCase() };
  }
}
