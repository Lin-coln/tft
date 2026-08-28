import { screenshot } from "../src/screenshot.ts";

await Bun.write("screenshot.png", await screenshot());
