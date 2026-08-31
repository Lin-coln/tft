import { create, pick } from "./addon.ts";

export type Window = {
  id: number;
  name: string;
  owner_name: string;
};

export interface Screenshot {
  getWindowId(): number;
  screenshot(): Uint8Array;
}

declare module "./addon.ts" {
  interface Addon {
    listWindows(): Window[];
    Screenshot: new (windowId: number) => Screenshot;
  }
}

export const listWindows = /* @__PURE__ */ pick((x) => x.listWindows);

export const Screenshot = /* @__PURE__ */ create((get) => get().Screenshot);
