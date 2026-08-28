import * as ort from "onnxruntime-node";
import sharp from "sharp";
import { resolve } from "node:path";

export type ImageFilenameOrBytes = string | ArrayBuffer | Uint8Array;

interface Rectangle {
  left: number;
  top: number;
  width: number;
  height: number;
}

export interface ShopSlot {
  slot: number;
  name: string;
  confidence: number;
}

export interface ResolvedInfo {
  shop: ShopSlot[];
}

interface AnchorProfile {
  offsetX: number;
  offsetY: number;
  width: number;
  height: number;
}

interface OcrRuntime {
  detSession: ort.InferenceSession;
  recSession: ort.InferenceSession;
  characters: string[];
}

const ROOT = resolve(import.meta.dir, "..");
const DET_MODEL_PATH = resolve(ROOT, "assets/models/ppocrv5_mobile_det.onnx");
const REC_MODEL_PATH = resolve(ROOT, "assets/models/ppocrv5_mobile_rec.onnx");
const REC_CONFIG_PATH = resolve(ROOT, "assets/models/ppocrv5_mobile_rec.yml");
const BASE_HEIGHT = 910;

// 以画面底部中心为锚点，来自 JinChanChanTool 的 1600x910 金铲铲模板。
const SHOP_NAME_PROFILES: AnchorProfile[] = [
  { offsetX: -300, offsetY: -29, width: 91, height: 26 },
  { offsetX: -120, offsetY: -29, width: 91, height: 24 },
  { offsetX: 53, offsetY: -30, width: 88, height: 27 },
  { offsetX: 229, offsetY: -28, width: 86, height: 27 },
  { offsetX: 406, offsetY: -29, width: 93, height: 26 },
];

let runtimePromise: Promise<OcrRuntime> | undefined;

export async function resolve_info(imageFilenameOrBytes: ImageFilenameOrBytes): Promise<ResolvedInfo> {
  const image = toSharpInput(imageFilenameOrBytes);
  const [metadata, runtime] = await Promise.all([sharp(image).metadata(), getRuntime()]);
  if (!metadata.width || !metadata.height) throw new Error("invalid image");

  const rectangles = SHOP_NAME_PROFILES.map((profile) =>
    calculateRectangle(profile, metadata.width!, metadata.height!),
  );
  const shop = await Promise.all(
    rectangles.map(async (rectangle, index): Promise<ShopSlot> => {
      const slotImage = await sharp(image).extract(rectangle).png().toBuffer();
      const textRectangle = await detectText(runtime.detSession, slotImage);
      const textImage = await sharp(slotImage).extract(textRectangle).png().toBuffer();
      const result = await recognizeText(runtime.recSession, textImage, runtime.characters);

      return {
        slot: index + 1,
        name: result.text,
        confidence: result.confidence,
      };
    }),
  );

  return { shop };
}

function getRuntime(): Promise<OcrRuntime> {
  runtimePromise ??= Promise.all([
    ort.InferenceSession.create(DET_MODEL_PATH, { logSeverityLevel: 3 }),
    ort.InferenceSession.create(REC_MODEL_PATH, { logSeverityLevel: 3 }),
    loadCharacters(REC_CONFIG_PATH),
  ]).then(([detSession, recSession, characters]) => ({ detSession, recSession, characters }));

  return runtimePromise;
}

function loadCharacters(path: string): Promise<string[]> {
  return Bun.file(path)
    .text()
    .then((yaml) => {
      const config = Bun.YAML.parse(yaml) as {
        PostProcess?: { character_dict?: unknown };
      };
      const characters = config.PostProcess?.character_dict;
      if (!Array.isArray(characters) || !characters.every((character) => typeof character === "string")) {
        throw new Error("character_dict was not found in recognition config");
      }

      return ["", ...characters, " "];
    });
}

async function detectText(session: ort.InferenceSession, image: Buffer): Promise<Rectangle> {
  const metadata = await sharp(image).metadata();
  if (!metadata.width || !metadata.height) throw new Error("invalid shop slot image");

  const inputWidth = roundTo32(metadata.width);
  const inputHeight = roundTo32(metadata.height);
  const { data } = await sharp(image)
    .removeAlpha()
    .resize(inputWidth, inputHeight, { fit: "fill" })
    .raw()
    .toBuffer({ resolveWithObject: true });

  const input = toDetTensor(data, inputWidth, inputHeight);
  const output = (await session.run({ x: input })).fetch_name_0;
  if (!output) throw new Error("detection model returned no output");

  const probabilities = output.data as Float32Array;
  const [, , outputHeight, outputWidth] = output.dims;
  if (!outputWidth || !outputHeight) throw new Error("invalid detection model output shape");

  let minX = outputWidth;
  let minY = outputHeight;
  let maxX = -1;
  let maxY = -1;

  for (let y = 0; y < outputHeight; y++) {
    for (let x = 0; x < outputWidth; x++) {
      if ((probabilities[y * outputWidth + x] ?? 0) < 0.3) continue;
      minX = Math.min(minX, x);
      minY = Math.min(minY, y);
      maxX = Math.max(maxX, x);
      maxY = Math.max(maxY, y);
    }
  }

  if (maxX < minX || maxY < minY) {
    return { left: 0, top: 0, width: metadata.width, height: metadata.height };
  }

  const scaleX = metadata.width / outputWidth;
  const scaleY = metadata.height / outputHeight;
  const left = Math.max(0, Math.floor(minX * scaleX) - 2);
  const top = Math.max(0, Math.floor(minY * scaleY) - 2);
  const right = Math.min(metadata.width, Math.ceil((maxX + 1) * scaleX) + 2);
  const bottom = Math.min(metadata.height, Math.ceil((maxY + 1) * scaleY) + 2);

  return { left, top, width: right - left, height: bottom - top };
}

async function recognizeText(
  session: ort.InferenceSession,
  image: Buffer,
  characters: string[],
): Promise<{ text: string; confidence: number }> {
  const metadata = await sharp(image).metadata();
  if (!metadata.width || !metadata.height) throw new Error("invalid detected text image");

  const inputHeight = 48;
  const inputWidth = 320;
  const resizedWidth = Math.min(inputWidth, Math.max(1, Math.ceil((inputHeight * metadata.width) / metadata.height)));
  const { data } = await sharp(image)
    .removeAlpha()
    .resize(resizedWidth, inputHeight, { fit: "fill" })
    .raw()
    .toBuffer({ resolveWithObject: true });

  const input = toRecTensor(data, resizedWidth, inputWidth, inputHeight);
  const output = (await session.run({ x: input })).fetch_name_0;
  if (!output) throw new Error("recognition model returned no output");

  const logits = output.data as Float32Array;
  const [, steps, classes] = output.dims;
  if (!steps || !classes) throw new Error("invalid recognition model output shape");

  const text: string[] = [];
  const scores: number[] = [];
  let previous = 0;

  for (let step = 0; step < steps; step++) {
    const offset = step * classes;
    let bestIndex = 0;
    let bestScore = logits[offset] ?? -Infinity;

    for (let index = 1; index < classes; index++) {
      const score = logits[offset + index] ?? -Infinity;
      if (score <= bestScore) continue;
      bestIndex = index;
      bestScore = score;
    }

    if (bestIndex !== 0 && bestIndex !== previous) {
      text.push(characters[bestIndex] ?? "");
      scores.push(bestScore);
    }
    previous = bestIndex;
  }

  return {
    text: text.join("").trim(),
    confidence: scores.length ? scores.reduce((sum, score) => sum + score, 0) / scores.length : 0,
  };
}

function calculateRectangle(profile: AnchorProfile, imageWidth: number, imageHeight: number): Rectangle {
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

function toSharpInput(input: ImageFilenameOrBytes): string | Buffer {
  if (typeof input === "string") return input;
  if (input instanceof ArrayBuffer) return Buffer.from(input);
  return Buffer.from(input.buffer, input.byteOffset, input.byteLength);
}

function toDetTensor(data: Buffer, width: number, height: number): ort.Tensor {
  const pixels = width * height;
  const tensor = new Float32Array(pixels * 3);
  const mean = [0.485, 0.456, 0.406];
  const std = [0.229, 0.224, 0.225];

  for (let index = 0; index < pixels; index++) {
    for (let channel = 0; channel < 3; channel++) {
      const bgr = data[index * 3 + (2 - channel)] ?? 0;
      tensor[channel * pixels + index] = (bgr / 255 - mean[channel]!) / std[channel]!;
    }
  }

  return new ort.Tensor("float32", tensor, [1, 3, height, width]);
}

function toRecTensor(data: Buffer, resizedWidth: number, width: number, height: number): ort.Tensor {
  const plane = width * height;
  const tensor = new Float32Array(plane * 3);

  for (let y = 0; y < height; y++) {
    for (let x = 0; x < resizedWidth; x++) {
      const source = (y * resizedWidth + x) * 3;
      const target = y * width + x;

      for (let channel = 0; channel < 3; channel++) {
        const bgr = data[source + (2 - channel)] ?? 0;
        tensor[channel * plane + target] = bgr / 127.5 - 1;
      }
    }
  }

  return new ort.Tensor("float32", tensor, [1, 3, height, width]);
}

function roundTo32(value: number): number {
  return Math.max(32, Math.round(value / 32) * 32);
}
