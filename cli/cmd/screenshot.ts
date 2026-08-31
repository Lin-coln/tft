import { Command } from "commander";
import { dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { mkdir } from "node:fs/promises";
import { InvalidArgumentError } from "commander";
import { Screenshot } from "@tft/graphics";

export const command = new Command("screenshot")
  .description("Capture a screenshot of a window")
  .requiredOption("-i, --id <id>", "window ID", parseWindowId)
  .option("--out <filename>", "output PNG filename")

  .action(async (opts: { id: number; out?: string }) => {
    const out = resolve(opts.out ?? join(tmpdir(), `tft-screenshot-${Date.now()}.png`));

    await mkdir(dirname(out), { recursive: true });

    await Bun.write(out, new Screenshot(opts.id).screenshot());

    process.stdout.write(`${out}\n`);
  });

function parseWindowId(value: string): number {
  const id = Number(value);
  if (!Number.isSafeInteger(id) || id <= 0) {
    throw new InvalidArgumentError("window ID must be a positive integer");
  }
  return id;
}
