import { describe, expect, test } from "bun:test";

import { listWindows } from "../src";

describe("window native addon", () => {
  test("lists windows with complete fields", () => {
    const windows = listWindows();

    expect(windows.length).toBeGreaterThan(0);
    for (const window of windows) {
      expect(typeof window.id).toBe("number");
      expect(typeof window.name).toBe("string");
      expect(window.name.length).toBeGreaterThan(0);
      expect(typeof window.owner_name).toBe("string");
      expect(window.owner_name.length).toBeGreaterThan(0);
    }
  });
});
