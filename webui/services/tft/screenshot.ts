import { resolve_shop, resolve_level, resolve_currency } from "@tft/core";
import { screenshot as captureScreenshot } from "@tft/graphics";
import { store } from "./utils.ts";
import { deepStrictEqual } from "node:assert";

export async function screenshot() {
  const window_id = store.getState().window_id;
  if (window_id < 0) {
    throw new Error("No window selected");
  }

  const bytes = captureScreenshot(window_id);

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
