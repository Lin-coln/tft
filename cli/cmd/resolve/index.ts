import { Command } from "commander";
import { resolve } from "node:path";
import { resolve_shop, resolve_level, resolve_currency } from "@tft/resolve";

export const command = new Command("resolve")
  .description("Resolve TFT information from a piped image path")

  .action(async () => {
    const target = await readTargetFromStdin();

    const [shop, level, economy] = await Promise.all([
      resolve_shop(target),
      resolve_level(target),
      resolve_currency(target),
    ]);

    const info = { shop, level, economy };

    process.stdout.write(`${JSON.stringify(info)}\n`);
  });

async function readTargetFromStdin(): Promise<string> {
  if (process.stdin.isTTY) throw new Error("missing piped screenshot path");

  const target = (await Bun.stdin.text()).trim();
  if (!target) throw new Error("missing piped screenshot path");
  return resolve(target);
}
