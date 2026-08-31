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

// 1600x910 游戏内容坐标；截图顶部可能额外包含窗口 frame。
const ECONOMY_PROFILE: AnchorProfile = {
  offsetX: 39,
  offsetY: -210,
  width: 76,
  height: 65,
};

export async function resolve_currency(
  imageFilenameOrBytes: ImageFilenameOrBytes,
): Promise<EconomyInfo> {
  const image = toSharpInput(imageFilenameOrBytes);
  const metadata = await sharp(image).metadata();
  if (!metadata.width || !metadata.height) throw new Error("invalid image");

  const panel = calculateRectangle(ECONOMY_PROFILE, metadata.width, metadata.height);
  const valueImage = await sharp(image).extract(panel).grayscale().normalize().png().toBuffer();
  const result = await recognizeText(valueImage);
  const economy = Number(result.text.match(/\d+/)?.[0]);
  if (!Number.isInteger(economy)) throw new Error(`unable to resolve economy: ${result.text}`);
  return { current: economy, confidence: result.confidence };
}
