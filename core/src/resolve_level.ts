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

// 1600x910 基准图：完整等级/经验面板约为 (280, 702) - (434, 750)。
const LEVEL_PROFILE: AnchorProfile = {
  offsetX: -443,
  offsetY: -184,
  width: 154,
  height: 48,
};

export async function resolve_level(
  imageFilenameOrBytes: ImageFilenameOrBytes,
): Promise<LevelInfo> {
  const image = toSharpInput(imageFilenameOrBytes);
  const metadata = await sharp(image).metadata();
  if (!metadata.width || !metadata.height) throw new Error("invalid image");

  const panel = calculateRectangle(LEVEL_PROFILE, metadata.width, metadata.height);
  const scale = metadata.height / 910;
  const levelRectangle = {
    left: Math.round(7 * scale),
    top: Math.round(4 * scale),
    width: Math.round(64 * scale),
    height: Math.round(34 * scale),
  };
  const experienceRectangle = {
    left: Math.round(96 * scale),
    top: Math.round(4 * scale),
    width: Math.round(55 * scale),
    height: Math.round(34 * scale),
  };
  const panelImage = sharp(image).extract(panel);
  const [levelResult, experienceResult] = await Promise.all([
    panelImage.clone().extract(levelRectangle).png().toBuffer().then(recognizeText),
    panelImage.clone().extract(experienceRectangle).png().toBuffer().then(recognizeText),
  ]);

  const level = Number(levelResult.text.match(/\d+/)?.[0]);
  const experience = experienceResult.text.match(/(\d+)\s*[/／]\s*(\d+)/);
  if (!Number.isInteger(level)) throw new Error(`unable to resolve level: ${levelResult.text}`);
  if (!experience) throw new Error(`unable to resolve experience: ${experienceResult.text}`);

  const current = Number(experience[1]);
  const required = Number(experience[2]);
  return {
    current: level,
    confidence: levelResult.confidence,
    experience: {
      current,
      required,
      confidence: experienceResult.confidence,
    },
  };
}
