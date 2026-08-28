import { dlopen, FFIType, suffix } from "bun:ffi";
import { join } from "node:path";

const libraryDirectory = process.platform === "win32" ? "bin" : "lib";
const libraryName = process.platform === "win32" ? `calc.${suffix}` : `libcalc.${suffix}`;
const libraryPath = join(import.meta.dir, "..", "zig-out", libraryDirectory, libraryName);

const library = dlopen(libraryPath, {
  add: {
    args: [FFIType.f64, FFIType.f64],
    returns: FFIType.f64,
  },
  subtract: {
    args: [FFIType.f64, FFIType.f64],
    returns: FFIType.f64,
  },
  multiply: {
    args: [FFIType.f64, FFIType.f64],
    returns: FFIType.f64,
  },
  divide: {
    args: [FFIType.f64, FFIType.f64],
    returns: FFIType.f64,
  },
});

export const { add, subtract, multiply, divide } = library.symbols;

export function closeCalc(): void {
  library.close();
}

if (import.meta.main) {
  console.log("2 + 3 =", add(2, 3));
  console.log("2 - 3 =", subtract(2, 3));
  console.log("2 * 3 =", multiply(2, 3));
  console.log("5 / 2 =", divide(5, 2));
  closeCalc();
}
