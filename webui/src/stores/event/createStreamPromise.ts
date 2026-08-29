import type { ServerEvent } from "@shared/index.ts";
import { toServerEventStream } from "./toServerEventStream.ts";

export function createStreamPromise(opts: {
  handleRequest: (signal: AbortSignal) => Promise<Response>;
  handleReconnect: () => void;
  onEvent: (event: ServerEvent) => void;
  onDispose: () => void;
}) {
  const ctrl = new AbortController();
  const handleRequest = opts.handleRequest;
  const onEvent = opts.onEvent;
  const onDispose = opts.onDispose;
  const handleReconnect = opts.handleReconnect;

  return Object.assign(
    Promise.resolve()
      .then(async () => {
        const resp = await handleRequest(ctrl.signal);
        if (!resp.ok) {
          throw new Error(`failed to fetch - ${resp.status} ${resp.statusText}`);
        }
        if (!resp.body) {
          throw new Error(`failed to fetch - empty body`);
        }

        const stream = toServerEventStream(resp.body, ctrl.signal);
        for await (const event of stream) {
          onEvent(event);
          if (ctrl.signal.aborted) return;
        }
      })
      .catch(handleError),
    {
      dispose: () => {
        onDispose();
        ctrl.abort();
      },
    },
  );

  async function handleError(err: unknown) {
    if (err && typeof err === "object" && "name" in err && err.name === "AbortError") {
      return;
    }

    const message = err instanceof Error ? err.message : String(err);
    if (["network error", "Failed to fetch"].includes(message)) {
      await new Promise((resolve) => setTimeout(resolve, 3_000));
      handleReconnect();
      return;
    }

    // unexpected
    console.error(`[server-event]`, message);
    console.error(err);
    await new Promise((resolve) => setTimeout(resolve, 3_000));
    handleReconnect();
  }
}
