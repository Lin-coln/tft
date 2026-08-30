import { create } from "zustand";
import { subscribe } from "@stores/event";
import type { TFTState } from "@shared/index.ts";
import { toAction } from "./invoke.ts";
import { getSnapshot } from "./getSnapshot.ts";

const initialState: TFTState = await getSnapshot();
const store = create<TFTState>((set, _get, api) => {
  subscribe((evt) => {
    if (!("event" in evt)) return;
    if (!evt.event.startsWith("service.snapshot.tft")) return;
    set(evt.data);
  });
  return initialState;
});

export const useTFTStore = store;

export const start = /* @__PURE__ */ toAction("start");
export const stop = /* @__PURE__ */ toAction("stop");
export const screenshot = /* @__PURE__ */ toAction("screenshot");
export const listWindows = /* @__PURE__ */ toAction("listWindows");
export const setWindowId = /* @__PURE__ */ toAction("setWindowId");
