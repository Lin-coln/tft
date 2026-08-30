import { describe, expect, test } from "bun:test";

import { screenshot } from "../src";

describe("screenshot native addon", () => {
  test("rejects the null window id", () => {
    expect(() => screenshot(0)).toThrow("InvalidWindowId");
  });
});
