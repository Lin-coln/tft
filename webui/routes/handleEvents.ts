import { on } from "@services/sse/index.ts";
import type { ServerEvent } from "@shared/index.ts";

export const handleEvents = {
  GET(req: Bun.BunRequest<"/api/events">, server: Bun.Server<void>) {
    const clientId = req.headers.get("x-client-id");
    if (!clientId) {
      return new Response("client id not found", { status: 403 });
    }

    server.timeout(req, 0);

    return new Response(createStream(clientId, req.signal), {
      headers: {
        "Content-Type": "application/octet-stream",
        "Cache-Control": "no-cache, no-transform",
      },
    });
  },
};

function createStream(clientId: string, signal: AbortSignal) {
  let conn: ReturnType<typeof createConnection>;

  return new ReadableStream<Uint8Array>({
    async start(ctrl) {
      conn = createConnection(ctrl);

      // abort
      if (signal) {
        const handleAbort = () => conn.dispose("aborted");
        signal.addEventListener("abort", handleAbort, { once: true });
        conn.onDispose(() => signal.removeEventListener("abort", handleAbort));
      }

      // attach
      try {
        const off = on(clientId, (event) => {
          conn.send(event);
        });
        conn.onDispose(off);
      } catch (err) {
        console.error(`failed to attach connection:`, err);
        conn.dispose(`failed to attach connection`);
        return;
      }

      // heartbeat
      const heartbeat = setInterval(() => conn.send({ comment: "ping" }), 15_000);
      conn.onDispose(() => clearInterval(heartbeat));

      // connected
      conn.send({ comment: "connected" });
    },

    cancel() {
      conn.dispose();
    },
  });
}

function createConnection(ctrl: Bun.ReadableStreamController<any>) {
  let disposed = false;
  const callbacks = new Set<(reason?: string) => void>();
  return {
    isDisposed: () => disposed,
    dispose: (reason?: string) => {
      if (disposed) return;
      disposed = true;
      for (const cb of callbacks) {
        cb(reason);
      }
    },
    onDispose: (cb: (reason?: string) => void) => {
      callbacks.add(cb);
      return () => callbacks.delete(cb);
    },
    send: (event: ServerEvent) => {
      if ("comment" in event) {
        ctrl.enqueue(`: ${event.comment}\n\n`);
        return;
      }

      let chunk = "";
      if (event.event && event.event !== "message") {
        chunk += `event: ${event.event}\n`;
      }
      chunk += `data: ${JSON.stringify(event.data)}\n`;
      chunk += "\n";
      ctrl.enqueue(chunk);
    },
  };
}
