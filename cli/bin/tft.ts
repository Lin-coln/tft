#!/usr/bin/env bun

import { Command } from "commander";
import { resolve } from "node:path";
import { existsSync } from "node:fs";

try {
  const [_bun, tft, ...argv] = process.argv;
  if (tft !== import.meta.filename) {
    throw new Error("failed to resolve argv");
  }

  const chain: CommandInfo[] = [];
  let dir = resolve(import.meta.dirname, "../cmd");
  for (const arg of argv) {
    if (arg.startsWith("-")) break;

    const info = resolveCommandInfo(arg, dir);
    if (!info) break;

    chain.push(info);
    if (info.isLeaf) break;
    dir = info.nextDirname;
  }

  const program = new Command("tft");
  let parent = program;
  await Promise.all(chain.map((x) => x.toCommand())).then((arr: Command[]) =>
    arr.forEach((cmd) => {
      parent.addCommand(cmd);
      parent = cmd;
    }),
  );
  await program.parseAsync(argv, { from: "user" });
} catch (error) {
  process.stderr.write(`${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}

type CommandInfo = {
  readonly name: string;
  readonly isLeaf: boolean;
  readonly nextDirname: string;
  toCommand(): Promise<Command>;
};

function resolveCommandInfo(name: string, dir: string): CommandInfo | void {
  let filename = resolve(dir, `${name}.ts`);
  if (existsSync(filename)) {
    return {
      name,
      isLeaf: true,
      nextDirname: dir,
      toCommand: () => import(filename).then(resolveCommand),
    };
  }

  filename = resolve(dir, `${name}/index.ts`);
  if (existsSync(filename)) {
    return {
      name,
      isLeaf: false,
      nextDirname: resolve(dir, name),
      toCommand: () => import(filename).then(resolveCommand),
    };
  }
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
