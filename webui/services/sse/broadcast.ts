import type { ServerEvent } from "@shared/index.ts";
import { getState } from "./utils.ts";

export async function broadcast(event: ServerEvent) {
  const arr = Array.from(getState().subscribers.values(), (x) => Array.from(x)).flat();
  if (!arr) return;
  for (const cb of arr) await cb(event);
}
