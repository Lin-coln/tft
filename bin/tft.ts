#!/usr/bin/env bun

import { mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { Command } from "commander";

import { resolve_info } from "../src/resolve_info.ts";
import { screenshot } from "../src/screenshot.ts";

interface ScreenshotOptions {
  out?: string;
}

const program = new Command();

program.name("tft");

program
  .command("screenshot")
  .description("Capture the current LDPlayer screen")
  .option("--out <filename>", "output PNG filename")
  .action(async (options: ScreenshotOptions) => {
    const output = resolve(options.out ?? join(tmpdir(), `tft-screenshot-${Date.now()}.png`));
    await mkdir(dirname(output), { recursive: true });
    await Bun.write(output, await screenshot());
    process.stdout.write(`${output}\n`);
  });

program
  .command("resolve_info")
  .description("Resolve TFT information from a piped image path")
  .action(async () => {
    const target = await readTargetFromStdin();
    const info = await resolve_info(target);
    process.stdout.write(`${JSON.stringify(info, null, 2)}\n`);
  });

await program.parseAsync().catch((error: unknown) => {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
});

async function readTargetFromStdin(): Promise<string> {
  if (process.stdin.isTTY) throw new Error("missing piped screenshot path");

  const target = (await Bun.stdin.text()).trim();
  if (!target) throw new Error("missing piped screenshot path");
  return resolve(target);
}
