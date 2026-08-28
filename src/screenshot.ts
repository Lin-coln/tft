import { unlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { $ } from "bun";

const LDPLAYER_DIR = "C:\\leidian\\LDPlayer14";

export async function screenshot(): Promise<Uint8Array> {
  const adbPath = join(LDPLAYER_DIR, "adb.exe");
  const name = `bun-screenshot-${process.pid}-${Date.now()}.png`;
  const remoteTemp = `/sdcard/${name}`;
  const localTemp = join(tmpdir(), name);

  try {
    await $`${adbPath} shell screencap -p ${remoteTemp}`.quiet();
    await $`${adbPath} pull ${remoteTemp} ${localTemp}`.quiet();
    return await Bun.file(localTemp).bytes();
  } finally {
    await $`${adbPath} shell rm -f ${remoteTemp}`.quiet().nothrow();
    await unlink(localTemp).catch(() => undefined);
  }
}
