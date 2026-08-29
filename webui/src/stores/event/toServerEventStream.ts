import type { ServerEvent } from "@shared/index.ts";

export async function* toServerEventStream(
  readable: ReadableStream<Uint8Array>,
  signal: AbortSignal,
) {
  const stream = toAsyncIterable(readable);
  const decoder = new TextDecoder();
  let buffer = "";

  if (signal.aborted) return;

  for await (const chunk of stream) {
    if (signal.aborted) return;

    buffer += decoder.decode(chunk, { stream: true });

    while (true) {
      const idx = buffer.indexOf("\n\n");
      if (idx < 0) break;

      const part = buffer.slice(0, idx);
      buffer = buffer.slice(idx + 2);
      yield decodeServerEvent(part);
    }
  }

  // decode rest buffer
  try {
    yield decodeServerEvent(buffer);
  } catch {
    // noop, incomplete buffer
  }
}

function decodeServerEvent(part: string): ServerEvent {
  if (part.startsWith(": ")) {
    return { comment: part.slice(2).trim() };
  }

  const lines = part.split("\n").filter(Boolean);
  let event = "message";
  let data = "";
  for (const line of lines) {
    if (line.startsWith("event:")) {
      event = line.slice(6).trim();
    }
    if (line.startsWith("data:")) {
      data += line.slice(5).trim();
    }
  }

  return { event, data: JSON.parse(data) };
}

function toAsyncIterable(stream: ReadableStream<Uint8Array>) {
  const reader = stream.getReader();
  return {
    async *[Symbol.asyncIterator]() {
      try {
        while (true) {
          const { value, done } = await reader.read();
          if (done) return;
          yield value;
        }
      } finally {
        reader.releaseLock();
      }
    },
  };
}
