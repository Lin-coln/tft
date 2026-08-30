import { createRequire } from "node:module";

export interface Addon {}

let addon: Addon | null = null;

const require = /* @__PURE__ */ createRequire(import.meta.url);

export function getAddon(): Addon {
  return (addon ??= require("../../zig-out/lib/addon.node") as Addon);
}

export function createFunction<Fn extends (...args: any[]) => any>(cb: (addon: Addon) => Fn): Fn {
  return ((...args: any[]) => cb(getAddon()).apply(void 0, args)) as Fn;
}
