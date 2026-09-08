import { describe, expect, test } from "bun:test";

import { Runtime, listWindows } from "../src";

describe("screenshot native addon", () => {
  test("exposes screenshot as an instance method", () => {
    expect(Runtime.prototype.screenshot).toBeFunction();
  });

  test("rejects the null window id", () => {
    const runtime = new Runtime();
    expect(() => runtime.updateTarget(0)).toThrow("InvalidWindowId");
  });

  test("creates a native class instance", () => {
    const window = listWindows()[0];
    expect(window).toBeDefined();

    const runtime = new Runtime();
    runtime.updateTarget(window!.id);
    expect(runtime).toBeInstanceOf(Runtime);
    expect(runtime.getTarget()).toBe(window!.id);
  });
});
