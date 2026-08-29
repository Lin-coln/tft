#!/usr/bin/env bun

import { Command } from "commander";
import { resolve } from "node:path";
import { existsSync } from "node:fs";
import { readdir } from "node:fs/promises";

try {
  const [_bun, tft, ...argv] = process.argv;
  if (tft !== import.meta.filename) {
    throw new Error("failed to resolve argv");
  }

  const chain: [...CommandInfo[], CommandInfo | CommandInfo[]] = [] as any;
  let dir = resolve(import.meta.dirname, "../cmd");
  for (const arg of argv) {
    // command
    if (!arg.startsWith("-")) {
      const info = resolveCommandInfo(arg, dir);
      if (!info) break;

      chain.push(info);
      if (!info.nextDirname) break;
      dir = info.nextDirname;
      continue;
    }

    // option: -h
    if (["-h", "--help"].includes(arg)) {
      // load children commands for show helps
      chain.push(await resolveNestedCommandInfos(dir));
    }

    break;
  }

  const program = new Command("tft");
  let parent = program;
  await Promise.all(
    chain.map((x) => {
      if (!Array.isArray(x)) {
        return x.toCommand();
      } else {
        return Promise.all(x.map((x) => x.toCommand()));
      }
    }),
  ).then((arr) => {
    return arr.forEach((x: Command | Command[]) => {
      if (!Array.isArray(x)) {
        parent.addCommand(x);
        parent = x;
      } else {
        x.forEach((x) => parent.addCommand(x));
      }
    });
  });
  await program.parseAsync(argv, { from: "user" });
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}

type CommandInfo = {
  readonly name: string;
  readonly nextDirname: string | null;
  toCommand(): Promise<Command>;
};

function resolveCommandInfo(name: string, dir: string): CommandInfo | void {
  let filename = resolve(dir, `${name}.ts`);
  if (existsSync(filename)) {
    return {
      name,
      nextDirname: null,
      toCommand: () => import(filename).then(resolveCommand),
    };
  }

  filename = resolve(dir, `${name}/index.ts`);
  if (existsSync(filename)) {
    return {
      name,
      nextDirname: resolve(dir, name),
      toCommand: () => import(filename).then(resolveCommand),
    };
  }
}

async function resolveNestedCommandInfos(dir: string) {
  const items = await readdir(dir, { withFileTypes: true });
  return items
    .map((x) => {
      if (x.name === "index.ts") return;
      return resolveCommandInfo(x.name, dir);
    })
    .filter((x) => !!x);
}

async function resolveCommand(module: unknown): Promise<Command> {
  if (!module || typeof module !== "object") {
    throw new Error("invalid module found");
  }

  if ("command" in module && module.command && typeof module.command === "object") {
    return module.command as Command;
  }

  if ("makeCommand" in module && module.makeCommand && typeof module.makeCommand === "function") {
    return module.makeCommand() as Promise<Command>;
  }

  throw new Error("failed to resolveCommand");
}
