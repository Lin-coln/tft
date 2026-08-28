import { mkdir } from "node:fs/promises";

/**
 * https://github.com/CommunityDragon/CDTB
 */

const url =
  "https://raw.communitydragon.org/latest/cdragon/tft/zh_cn.json";

const outputDir = "riot-data";
const output = `${outputDir}/tft.json`;

await mkdir(outputDir, { recursive: true });

const response = await fetch(url);

if (!response.ok) {
  throw new Error(
    `Failed to fetch TFT data: ${response.status} ${response.statusText}`,
  );
}

await Bun.write(output, await response.text());

console.log(`TFT data saved to ${output}`);
