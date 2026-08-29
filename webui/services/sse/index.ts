import type { ServerEvent } from "@shared/index.ts";
import { getState, withRateLimitQueue } from "./utils.ts";
import { send as _send } from "./send.ts";
import { broadcast as _broadcast } from "./broadcast.ts";

export const send = /* @__PURE__ */ withRateLimitQueue(_send);
export const broadcast = /* @__PURE__ */ withRateLimitQueue(_broadcast);

export function on(client_id: string, cb: (event: ServerEvent) => void) {
  const set = getState().subscribers.get(client_id) ?? new Set();
  getState().subscribers.set(client_id, set);
  set.add(cb);
  return () => set.delete(cb);
}
