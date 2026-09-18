import { defineConfig } from "oxfmt";

export default defineConfig({
  sortPackageJson: {},
  ignorePatterns: [
    "node_modules",
    "riot-data",
    "assets",
    ".zig-cache",
    "zig-out",
    "zig-pkg",
    "pkg",
  ],
});
