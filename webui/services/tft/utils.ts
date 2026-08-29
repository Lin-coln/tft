import { createHMR } from "@services/utils.ts";
import { createStore } from "zustand";
import { broadcast } from "@services/sse";
import type { TFTState } from "@shared/index.ts";

const getState = /* @__PURE__ */ createHMR<TFTState>("service/tft", () => ({
  status: "idle",
  level: {
    current: -1,
    confidence: 1,
    experience: { current: -1, required: -1, confidence: 1 },
  },
  currency: {
    current: -1,
    confidence: 1,
  },
  shop: [],
}));

export const store = createStore<TFTState>((set, get, api) => {
  api.subscribe((s) => {
    Object.assign(getState(), structuredClone(s));
  });

  api.subscribe(async (s) => {
    await broadcast({ event: "service.snapshot.tft", data: structuredClone(s) });
  });

  return structuredClone(getState());
});
