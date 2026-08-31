import { describe, expect, test } from "bun:test";

import { Screenshot, listWindows } from "../src";

describe("screenshot native addon", () => {
  test("exposes screenshot as an instance method", () => {
    expect(Screenshot.prototype.screenshot).toBeFunction();
  });

  test("rejects the null window id", () => {
    expect(() => new Screenshot(0)).toThrow("InvalidWindowId");
  });

  test("creates a native class instance", () => {
    const window = listWindows()[0];
    expect(window).toBeDefined();

    const instance = new Screenshot(window!.id);
    expect(instance).toBeInstanceOf(Screenshot);
    expect(instance.getWindowId()).toBe(window!.id);
  });
});
