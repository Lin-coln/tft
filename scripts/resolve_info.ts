import { resolve } from "node:path";

import { resolve_economy } from "../src/resolve_economy.ts";
import { resolve_level } from "../src/resolve_level.ts";
import { resolve_shop } from "../src/resolve_shop.ts";

const image = resolve(import.meta.dir, "../assets/images/img_4.png");
const [shop, level, economy] = await Promise.all([
  resolve_shop(image),
  resolve_level(image),
  resolve_economy(image),
]);
const info = { shop, level, economy };

console.log(JSON.stringify(info, null, 2));
