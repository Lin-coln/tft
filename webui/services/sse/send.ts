import type { ServerEvent } from "@shared/index.ts";
import { getState } from "./utils.ts";

export async function send(client_id: string, event: ServerEvent) {
  const set = getState().subscribers.get(client_id);
  if (!set) return;
  for (const cb of set) await cb(event);
}
