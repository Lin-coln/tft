import { resolve_shop, resolve_level, resolve_currency } from "@tft/resolve";
import { Runtime, type StreamConfig, type StreamPacket } from "@tft/graphics";
import { store } from "./utils.ts";
import { deepStrictEqual } from "node:assert";

let instance: Runtime | undefined;
const streamListeners = new Set<(packet: StreamPacket, config: StreamConfig) => void>();

export function subscribeStream(
  listener: (packet: StreamPacket, config: StreamConfig) => void,
): () => void {
  streamListeners.add(listener);
  void ensureInstance();
  return () => void streamListeners.delete(listener);
}

export async function screenshot() {
  const window_id = store.getState().window_id;
  if (window_id < 0) {
    throw new Error("No window selected");
  }

  const current = ensureInstance();
  if (!current) throw new Error("No window selected");

  const bytes = current.screenshot();

  const level = await resolve_level(bytes).catch(() => null);
  const currency = await resolve_currency(bytes).catch(() => null);
  const shop = await resolve_shop(bytes).catch(() => null);

  store.setState((s) => {
    if (level && !structuredEqual(s.level, level)) {
      s.level = level;
    }
    if (currency && !structuredEqual(s.currency, currency)) {
      s.currency = currency;
    }
    if (shop && !structuredEqual(s.shop, shop)) {
      s.shop = shop;
    }
    return { ...s };
  });

  return bytes;
}

function ensureInstance(): Runtime | null {
  const window_id = store.getState().window_id;
  if (window_id < 0) return null;

  if (!instance) {
    let next: Runtime;
    next = new Runtime((packet) => {
      const config = next.getStreamConfig();
      if (!config) return;
      for (const listener of streamListeners) listener(packet, config);
    });
    instance = next;
  }
  if (instance.getTarget() !== window_id) instance.updateTarget(window_id);
  return instance;
}

store.subscribe((state, prev) => {
  if (state.window_id === prev.window_id || streamListeners.size === 0) return;
  void ensureInstance();
});

function structuredEqual(obj1: object, obj2: object) {
  try {
    deepStrictEqual(obj1, obj2);
    return true;
  } catch {
    return false;
  }
}
