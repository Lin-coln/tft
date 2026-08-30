import { describe, expect, test } from "bun:test";
import { add, divide, multiply, subtract } from "../src";

describe("calc native addon", () => {
  test("adds numbers", () => {
    expect(add(2, 3)).toBe(5);
    expect(add(-2.5, 1.25)).toBe(-1.25);
  });

  test("subtracts numbers", () => {
    expect(subtract(2, 3)).toBe(-1);
    expect(subtract(1.25, -2.5)).toBe(3.75);
  });

  test("multiplies numbers", () => {
    expect(multiply(2, 3)).toBe(6);
    expect(multiply(-2.5, 1.25)).toBe(-3.125);
  });

  test("divides numbers", () => {
    expect(divide(5, 2)).toBe(2.5);
  });

  test("throws when dividing by zero", () => {
    expect(() => divide(1, 0)).toThrow("DivisionByZero");
  });
});
