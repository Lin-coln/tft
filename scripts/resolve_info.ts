import { resolve } from "node:path";

import { resolve_info } from "../src/resolve_info.ts";

const image = resolve(import.meta.dir, "../assets/images/img_2.png");
const info = await resolve_info(image);

console.log(JSON.stringify(info, null, 2));
