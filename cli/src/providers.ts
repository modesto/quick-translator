import type { RequestOptions, TranslationResult } from "./translate.js";

export const PROVIDER_IDS = ["claude-code", "claude-api", "deepl"] as const;
export type ProviderId = (typeof PROVIDER_IDS)[number];
export const DEFAULT_PROVIDER: ProviderId = "claude-code";

export function isProviderId(value: unknown): value is ProviderId {
  return typeof value === "string" && (PROVIDER_IDS as readonly string[]).includes(value);
}

export interface TranslationProvider {
  readonly id: ProviderId;
  readonly model: string;
  warmUp(): Promise<unknown>;
  translate(text: string, request: RequestOptions): Promise<TranslationResult>;
  close(): Promise<void>;
}

export const PROVIDER_ERROR_CODES = [
  "missing_key",
  "auth_failed",
  "quota_exceeded",
  "rate_limited",
  "unsupported_language",
  "refused",
  "network",
  "provider_error",
] as const;
export type ProviderErrorCode = (typeof PROVIDER_ERROR_CODES)[number];

export class ProviderError extends Error {
  constructor(
    readonly code: ProviderErrorCode,
    message: string,
  ) {
    super(message);
    this.name = "ProviderError";
  }
}

export const API_KEY_ENV = {
  "claude-api": "QT_ANTHROPIC_API_KEY",
  deepl: "QT_DEEPL_AUTH_KEY",
} as const;
