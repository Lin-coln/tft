import { Command } from "commander";
import { dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { mkdir } from "node:fs/promises";
import { screenshot } from "@tft/core";

export const command = new Command("screenshot")
  .description("Capture the current LDPlayer screen")
  .option("--out <filename>", "output PNG filename")

  .action(async (opts: { out?: string }) => {
    const out = resolve(opts.out ?? join(tmpdir(), `tft-screenshot-${Date.now()}.png`));

    await mkdir(dirname(out), { recursive: true });

    await Bun.write(out, await screenshot());

    process.stdout.write(`${out}\n`);
  });
