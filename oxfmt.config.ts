import { defineConfig } from "oxfmt";

export default defineConfig({
  sortPackageJson: {},
  ignorePatterns: [
    "node_modules",
    ".venv",
    "riot-data",
    "assets",
    ".zig-cache",
    ".zig-global-cache",
    "zig-out",
    "zig-pkg",
  ],
});
