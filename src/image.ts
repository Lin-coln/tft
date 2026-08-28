import { resolve } from "node:path";

export type ImageFilenameOrBytes = string | ArrayBuffer | Uint8Array;

export interface Rectangle {
  left: number;
  top: number;
  width: number;
  height: number;
}

export interface AnchorProfile {
  offsetX: number;
  offsetY: number;
  width: number;
  height: number;
}

export const ROOT = resolve(import.meta.dir, "..");

const BASE_HEIGHT = 910;

export function calculateRectangle(
  profile: AnchorProfile,
  imageWidth: number,
  imageHeight: number,
): Rectangle {
  const scale = imageHeight / BASE_HEIGHT;
  const width = Math.max(1, Math.round(profile.width * scale));
  const height = Math.max(1, Math.round(profile.height * scale));
  const anchorX = imageWidth / 2;
  const anchorY = imageHeight;
  const left = Math.max(0, Math.round(anchorX + profile.offsetX * scale - width / 2));
  const top = Math.max(0, Math.round(anchorY + profile.offsetY * scale - height / 2));

  return {
    left,
    top,
    width: Math.min(width, imageWidth - left),
    height: Math.min(height, imageHeight - top),
  };
}

export function toSharpInput(input: ImageFilenameOrBytes): string | Buffer {
  if (typeof input === "string") return input;
  if (input instanceof ArrayBuffer) return Buffer.from(input);
  return Buffer.from(input.buffer, input.byteOffset, input.byteLength);
}
