import { createInterface } from "node:readline";
import { WarmTranslator, type EngineOptions } from "./translate.js";

interface ServerRequest {
  id: string;
  text: string;
  to?: string;
  count?: number;
}

function send(message: Record<string, unknown>): void {
  process.stdout.write(JSON.stringify(message) + "\n");
}

function parseRequest(line: string): ServerRequest {
  const value: unknown = JSON.parse(line);
  if (typeof value !== "object" || value === null) throw new Error("Request must be a JSON object");
  const request = value as Record<string, unknown>;
  if (typeof request.id !== "string") throw new Error("Request needs a string 'id'");
  if (typeof request.text !== "string" || !request.text.trim()) throw new Error("Request needs a non-empty 'text'");
  return {
    id: request.id,
    text: request.text,
    to: typeof request.to === "string" ? request.to : undefined,
    count: typeof request.count === "number" ? request.count : undefined,
  };
}

export async function runServer(engine: EngineOptions, defaultCount: number): Promise<void> {
  const translator = new WarmTranslator(engine);
  translator.warmUp().then(
    () => send({ ready: true }),
    (error: unknown) => send({ ready: false, error: String(error) }),
  );

  const lines = createInterface({ input: process.stdin });
  for await (const line of lines) {
    if (!line.trim()) continue;
    let request: ServerRequest;
    try {
      request = parseRequest(line);
    } catch (error) {
      send({ id: null, error: error instanceof Error ? error.message : String(error) });
      continue;
    }

    translator
      .translate(request.text, { targetLanguage: request.to, count: request.count ?? defaultCount })
      .then(
        (result) => send({ id: request.id, result }),
        (error: unknown) => send({ id: request.id, error: error instanceof Error ? error.message : String(error) }),
      );
  }

  await translator.close();
  process.exit(0);
}
