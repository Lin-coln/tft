import { createRequire } from "node:module";
import { join } from "node:path";

interface CalcAddon {
  add(a: number, b: number): number;
  subtract(a: number, b: number): number;
  multiply(a: number, b: number): number;
  divide(a: number, b: number): number;
}

const require = createRequire(import.meta.url);
const addonPath = join(import.meta.dir, "..", "zig-out", "lib", "calc.node");
const addon = require(addonPath) as CalcAddon;

export const { add, subtract, multiply, divide } = addon;

if (import.meta.main) {
  console.log("2 + 3 =", add(2, 3));
  console.log("2 - 3 =", subtract(2, 3));
  console.log("2 * 3 =", multiply(2, 3));
  console.log("5 / 2 =", divide(5, 2));
}
