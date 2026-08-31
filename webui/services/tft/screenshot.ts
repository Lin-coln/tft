import { resolve_shop, resolve_level, resolve_currency } from "@tft/resolve";
import { Screenshot } from "@tft/graphics";
import { store } from "./utils.ts";
import { deepStrictEqual } from "node:assert";

let instance: Screenshot | undefined;

export async function screenshot() {
  const window_id = store.getState().window_id;
  if (window_id < 0) {
    throw new Error("No window selected");
  }

  if (!instance || instance.getWindowId() !== window_id) {
    instance = new Screenshot(window_id);
  }

  const bytes = instance.screenshot();

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

function structuredEqual(obj1: object, obj2: object) {
  try {
    deepStrictEqual(obj1, obj2);
    return true;
  } catch {
    return false;
  }
}
