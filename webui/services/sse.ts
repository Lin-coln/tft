import { createHMR } from "./utils.ts";
import type { ServerEvent } from "@shared/index.ts";

const getState = /* @__PURE__ */ createHMR("service/sse", () => {
  type Handler = (data: ServerEvent) => Promise<void> | void;
  return {
    subscribers: new Map<string, Set<Handler>>(), // <client_id, handlers>
  };
});

export const send = /* @__PURE__ */ withRateLimitQueue(
  async (client_id: string, event: ServerEvent) => {
    const set = getState().subscribers.get(client_id);
    if (!set) return;
    for (const cb of set) await cb(event);
  },
);

export function on(client_id: string, cb: (event: ServerEvent) => void) {
  const set = getState().subscribers.get(client_id) ?? new Set();
  getState().subscribers.set(client_id, set);
  set.add(cb);
  return () => set.delete(cb);
}

function withRateLimitQueue<Args extends any[]>(
  fn: (...args: Args) => Promise<void>,
  opts: { interval?: number } = {},
) {
  const { interval = 50 } = opts;
  const queue: Array<{ args: Args; resolve: () => void; reject: (err: unknown) => void }> = [];
  let running = false;

  return function (...args: Args): Promise<void> {
    return new Promise((resolve, reject) => {
      queue.push({ args, resolve, reject });
      void loop();
    });
  };

  async function loop() {
    if (running) return;
    running = true;
    while (queue.length > 0) {
      const task = queue.shift()!;
      try {
        await fn(...task.args);
        task.resolve();
      } catch (err) {
        task.reject(err);
      }
      if (interval > 0) {
        await sleep(interval);
      }
    }
    running = false;
  }
}

function sleep(ms: number) {
  return new Promise<void>((resolve) => {
    setTimeout(resolve, ms);
  });
}
