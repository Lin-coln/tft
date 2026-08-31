import sharp from "sharp";

import {
  calculateRectangle,
  toSharpInput,
  type AnchorProfile,
  type ImageFilenameOrBytes,
} from "./image.ts";
import { recognizeText } from "./ocr.ts";

export interface LevelInfo {
  current: number;
  confidence: number;
  experience: {
    current: number;
    required: number;
    confidence: number;
  };
}

// 1600x910 游戏内容坐标；截图顶部可能额外包含窗口 frame。
const LEVEL_PROFILE: AnchorProfile = {
  offsetX: -502,
  offsetY: -221,
  width: 217,
  height: 76,
};

export async function resolve_level(
  imageFilenameOrBytes: ImageFilenameOrBytes,
): Promise<LevelInfo> {
  const image = toSharpInput(imageFilenameOrBytes);
  const metadata = await sharp(image).metadata();
  if (!metadata.width || !metadata.height) throw new Error("invalid image");

  const panel = calculateRectangle(LEVEL_PROFILE, metadata.width, metadata.height);
  const result = await sharp(image).extract(panel).png().toBuffer().then(recognizeText);
  const match = result.text.match(/(\d+)\s*级\s*(\d+)\s*[/／]\s*(\d+)/);
  if (!match) throw new Error(`unable to resolve level: ${result.text}`);

  return {
    current: Number(match[1]),
    confidence: result.confidence,
    experience: {
      current: Number(match[2]),
      required: Number(match[3]),
      confidence: result.confidence,
    },
  };
}
