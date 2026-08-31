import sharp from "sharp";

import {
  calculateRectangle,
  toSharpInput,
  type AnchorProfile,
  type ImageFilenameOrBytes,
} from "./image.ts";
import { recognizeText } from "./ocr.ts";

export interface ShopSlot {
  slot: number;
  name: string;
  confidence: number;
}

const SHOP_NAME_PROFILES: AnchorProfile[] = [
  { offsetX: -300, offsetY: -29, width: 91, height: 26 },
  { offsetX: -120, offsetY: -29, width: 91, height: 24 },
  { offsetX: 53, offsetY: -30, width: 88, height: 27 },
  { offsetX: 229, offsetY: -28, width: 86, height: 27 },
  { offsetX: 406, offsetY: -29, width: 93, height: 26 },
];

export async function resolve_shop(
  imageFilenameOrBytes: ImageFilenameOrBytes,
): Promise<ShopSlot[]> {
  const image = toSharpInput(imageFilenameOrBytes);
  const metadata = await sharp(image).metadata();
  if (!metadata.width || !metadata.height) throw new Error("invalid image");

  return Promise.all(
    SHOP_NAME_PROFILES.map(async (profile, index): Promise<ShopSlot> => {
      const rectangle = calculateRectangle(profile, metadata.width!, metadata.height!);
      const slotImage = await sharp(image).extract(rectangle).png().toBuffer();
      const result = await recognizeText(slotImage);

      return { slot: index + 1, name: result.text, confidence: result.confidence };
    }),
  );
}
