import { createHMR } from "@services/utils.ts";
import { createStore } from "zustand";
import { broadcast } from "@services/sse";
import type { TFTState } from "@shared/index.ts";

const getState = /* @__PURE__ */ createHMR<TFTState>("service/tft", () => ({ status: "idle" }));

export const store = createStore<TFTState>((set, get, api) => {
  api.subscribe((s) => {
    Object.assign(getState(), structuredClone(s));
  });

  api.subscribe(async (s) => {
    await broadcast({ event: "service.snapshot.tft", data: structuredClone(s) });
  });

  return structuredClone(getState());
});

export async function start() {
  if (store.getState().status === "running") return;
  store.setState({ status: "running" });
}

export async function stop() {
  if (store.getState().status === "idle") return;
  store.setState({ status: "idle" });
}
