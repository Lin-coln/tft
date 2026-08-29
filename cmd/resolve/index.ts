import { Command } from "commander";
import { resolve } from "node:path";
import { resolve_shop } from "@/src/resolve_shop.ts";
import { resolve_level } from "@/src/resolve_level.ts";
import { resolve_economy } from "@/src/resolve_economy.ts";

export const command = new Command("resolve")
  .description("Resolve TFT information from a piped image path")

  .action(async () => {
    const target = await readTargetFromStdin();

    const [shop, level, economy] = await Promise.all([
      resolve_shop(target),
      resolve_level(target),
      resolve_economy(target),
    ]);

    const info = { shop, level, economy };

    process.stdout.write(`${JSON.stringify(info, null, 2)}\n`);
  });

async function readTargetFromStdin(): Promise<string> {
  if (process.stdin.isTTY) throw new Error("missing piped screenshot path");

  const target = (await Bun.stdin.text()).trim();
  if (!target) throw new Error("missing piped screenshot path");
  return resolve(target);
}
