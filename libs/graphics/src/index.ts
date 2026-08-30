import { createFunction } from "./addon";

export type * from "../types";

export const add = /* @__PURE__ */ createFunction((x) => x.add);
export const subtract = /* @__PURE__ */ createFunction((x) => x.subtract);
export const multiply = /* @__PURE__ */ createFunction((x) => x.multiply);
export const divide = /* @__PURE__ */ createFunction((x) => x.divide);

export const listWindows = /* @__PURE__ */ createFunction((x) => x.listWindows);
