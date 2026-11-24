import { createInterface } from "node:readline";
import { isValidCount, MAX_COUNT } from "./options.js";
import { WarmTranslator, type EngineOptions, type RequestOptions, type TranslationResult } from "./translate.js";

export interface ServerRequest {
  id: string;
  text: string;
  to?: string;
  count?: number;
}

export interface ServerTranslator {
  warmUp(): Promise<unknown>;
  translate(text: string, request: RequestOptions): Promise<TranslationResult>;
  close(): Promise<void>;
}

export type Send = (message: Record<string, unknown>) => void;

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
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
  return {
    id: request.id,
    text: request.text,
    to: typeof request.to === "string" ? request.to : undefined,
    count: request.count as number | undefined,
  };
}

export async function serve(
  translator: ServerTranslator,
  lines: AsyncIterable<string>,
  send: Send,
  settings: { model: string; defaultCount: number },
): Promise<void> {
  translator.warmUp().then(
    () => send({ ready: true, model: settings.model }),
    (error: unknown) => send({ ready: false, error: errorMessage(error) }),
  );

  const inFlight = new Set<Promise<void>>();
  for await (const line of lines) {
    if (!line.trim()) continue;
    let request: ServerRequest;
    try {
      request = parseRequest(line);
    } catch (error) {
      send({ id: null, error: errorMessage(error) });
      continue;
    }

    const work = translator
      .translate(request.text, { targetLanguage: request.to, count: request.count ?? settings.defaultCount })
      .then(
        (result) => send({ id: request.id, model: settings.model, result }),
        (error: unknown) => send({ id: request.id, error: errorMessage(error) }),
      );
    inFlight.add(work);
    work.finally(() => inFlight.delete(work));
  }

  await Promise.allSettled(inFlight);
  await translator.close();
}

export async function runServer(engine: EngineOptions, defaultCount: number): Promise<void> {
  await serve(
    new WarmTranslator(engine),
    createInterface({ input: process.stdin }),
    (message) => process.stdout.write(JSON.stringify(message) + "\n"),
    { model: engine.model, defaultCount },
  );
  process.exit(0);
}
