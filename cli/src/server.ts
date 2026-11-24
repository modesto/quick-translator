import { createInterface } from "node:readline";
import { ClaudeApiTranslator } from "./claudeApi.js";
import { DeepLTranslator } from "./deepl.js";
import { isValidCount, MAX_COUNT } from "./options.js";
import {
  API_KEY_ENV,
  isProviderId,
  PROVIDER_IDS,
  ProviderError,
  type ProviderId,
  type TranslationProvider,
} from "./providers.js";
import { WarmTranslator, type EngineOptions, type LanguagePair } from "./translate.js";

export interface ServerRequest {
  id: string;
  text: string;
  to?: string;
  count?: number;
  languagePair?: LanguagePair;
  provider?: ProviderId;
}

export type ProviderFactory = (id: ProviderId) => TranslationProvider;

export type Send = (message: Record<string, unknown>) => void;

export interface ServeSettings {
  defaultProvider: ProviderId;
  defaultCount: number;
  defaultLanguagePair?: LanguagePair;
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}

function errorResponse(id: string | null, error: unknown): Record<string, unknown> {
  const response: Record<string, unknown> = { id, error: errorMessage(error) };
  if (error instanceof ProviderError) response.code = error.code;
  return response;
}

export function parseRequest(line: string): ServerRequest {
  const value: unknown = JSON.parse(line);
  if (typeof value !== "object" || value === null || Array.isArray(value)) {
    throw new Error("Request must be a JSON object");
  }
  const request = value as Record<string, unknown>;
  if (typeof request.id !== "string") throw new Error("Request needs a string 'id'");
  if (typeof request.text !== "string" || !request.text.trim()) throw new Error("Request needs a non-empty 'text'");
  if (request.count !== undefined && !isValidCount(request.count)) {
    throw new Error(`'count' must be an integer between 1 and ${MAX_COUNT}`);
  }
  if (request.provider !== undefined && !isProviderId(request.provider)) {
    throw new Error(`'provider' must be one of ${PROVIDER_IDS.join(", ")}`);
  }
  return {
    id: request.id,
    text: request.text,
    to: typeof request.to === "string" ? request.to : undefined,
    count: request.count as number | undefined,
    languagePair: parseLanguagePair(request.mine, request.target),
    provider: request.provider as ProviderId | undefined,
  };
}

function parseLanguagePair(mine: unknown, target: unknown): LanguagePair | undefined {
  if (mine === undefined && target === undefined) return undefined;
  if (typeof mine !== "string" || !mine.trim() || typeof target !== "string" || !target.trim()) {
    throw new Error("'mine' and 'target' must be given together as non-empty strings");
  }
  if (mine.trim().toLowerCase() === target.trim().toLowerCase()) {
    throw new Error("'mine' and 'target' must be different languages");
  }
  return { mine: mine.trim(), target: target.trim() };
}

export class ProviderRegistry {
  private readonly providers = new Map<ProviderId, TranslationProvider>();

  constructor(private readonly create: ProviderFactory) {}

  get(id: ProviderId): TranslationProvider {
    let provider = this.providers.get(id);
    if (!provider) {
      provider = this.create(id);
      this.providers.set(id, provider);
    }
    return provider;
  }

  async closeAll(): Promise<void> {
    await Promise.allSettled([...this.providers.values()].map((provider) => provider.close()));
  }
}

export async function serve(registry: ProviderRegistry, lines: AsyncIterable<string>, send: Send, settings: ServeSettings): Promise<void> {
  const initial = registry.get(settings.defaultProvider);
  initial.warmUp().then(
    () => send({ ready: true, provider: initial.id, model: initial.model }),
    (error: unknown) => {
      const { id: _id, ...failure } = errorResponse(null, error);
      send({ ready: false, provider: initial.id, ...failure });
    },
  );

  const inFlight = new Set<Promise<void>>();
  for await (const line of lines) {
    if (!line.trim()) continue;
    let request: ServerRequest;
    try {
      request = parseRequest(line);
    } catch (error) {
      send(errorResponse(null, error));
      continue;
    }

    const provider = registry.get(request.provider ?? settings.defaultProvider);
    const work = provider
      .translate(request.text, {
        targetLanguage: request.to,
        count: request.count ?? settings.defaultCount,
        languagePair: request.languagePair ?? settings.defaultLanguagePair,
      })
      .then(
        (result) => send({ id: request.id, provider: provider.id, model: provider.model, result }),
        (error: unknown) => send({ ...errorResponse(request.id, error), provider: provider.id }),
      );
    inFlight.add(work);
    work.finally(() => inFlight.delete(work));
  }

  await Promise.allSettled(inFlight);
  await registry.closeAll();
}

export function defaultProviderFactory(engine: EngineOptions, apiModel: string, env: NodeJS.ProcessEnv): ProviderFactory {
  return (id) => {
    switch (id) {
      case "claude-code":
        return new WarmTranslator(engine);
      case "claude-api":
        return new ClaudeApiTranslator(apiModel, env[API_KEY_ENV["claude-api"]]?.trim() || undefined);
      case "deepl":
        return new DeepLTranslator(env[API_KEY_ENV.deepl]?.trim() || undefined);
    }
  };
}

export async function runServer(
  engine: EngineOptions,
  settings: ServeSettings & { apiModel: string },
): Promise<void> {
  await serve(
    new ProviderRegistry(defaultProviderFactory(engine, settings.apiModel, process.env)),
    createInterface({ input: process.stdin }),
    (message) => process.stdout.write(JSON.stringify(message) + "\n"),
    settings,
  );
  process.exit(0);
}
