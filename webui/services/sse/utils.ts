import { createHMR } from "@services/utils.ts";
import type { ServerEvent } from "@shared/index.ts";

export const getState = /* @__PURE__ */ createHMR("service/sse", () => {
  type Handler = (data: ServerEvent) => Promise<void> | void;
  return {
    subscribers: new Map<string, Set<Handler>>(), // <client_id, handlers>
  };
});

export function withRateLimitQueue<Args extends any[]>(
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
