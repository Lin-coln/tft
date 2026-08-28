import sharp from "sharp";

import {
  calculateRectangle,
  toSharpInput,
  type AnchorProfile,
  type ImageFilenameOrBytes,
} from "./image.ts";
import { recognizeText } from "./ocr.ts";

export interface EconomyInfo {
  current: number;
  confidence: number;
}

// 1600x910 基准图：完整金币面板约为 (733, 702) - (881, 748)。
const ECONOMY_PROFILE: AnchorProfile = {
  offsetX: 7,
  offsetY: -185,
  width: 148,
  height: 46,
};

export async function resolve_economy(
  imageFilenameOrBytes: ImageFilenameOrBytes,
): Promise<EconomyInfo> {
  const image = toSharpInput(imageFilenameOrBytes);
  const metadata = await sharp(image).metadata();
  if (!metadata.width || !metadata.height) throw new Error("invalid image");

  const panel = calculateRectangle(ECONOMY_PROFILE, metadata.width, metadata.height);
  const scale = metadata.height / 910;
  const panelImage = await sharp(image).extract(panel).png().toBuffer();
  const valueRectangle = await locateValueRectangle(panelImage, scale);
  const valueImage = await sharp(panelImage)
    .extract(valueRectangle)
    .png()
    .toBuffer();
  const result = await recognizeText(valueImage);
  const economy = Number(result.text.match(/\d+/)?.[0]);
  if (!Number.isInteger(economy)) throw new Error(`unable to resolve economy: ${result.text}`);
  return { current: economy, confidence: result.confidence };
}

async function locateValueRectangle(panelImage: Buffer, scale: number) {
  const { data, info } = await sharp(panelImage)
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  let firstTextX = info.width;

  for (let y = 0; y < info.height; y++) {
    for (let x = 0; x < info.width; x++) {
      const offset = (y * info.width + x) * 3;
      const red = data[offset] ?? 0;
      const green = data[offset + 1] ?? 0;
      const blue = data[offset + 2] ?? 0;
      const brightest = Math.max(red, green, blue);
      const darkest = Math.min(red, green, blue);

      // 金币数字接近白色；金币图标本身饱和度更高，不参与定位。
      if (darkest >= 120 && brightest - darkest <= 55) firstTextX = Math.min(firstTextX, x);
    }
  }

  if (firstTextX === info.width) throw new Error("unable to locate economy value");

  const left = Math.max(0, firstTextX - Math.round(3 * scale));
  const top = Math.round(3 * scale);
  return {
    left,
    top,
    width: Math.min(info.width - left, Math.round(65 * scale)),
    height: Math.min(info.height - top, Math.round(35 * scale)),
  };
}
