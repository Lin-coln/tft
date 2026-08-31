import * as ort from "onnxruntime-node";
import { resolve } from "node:path";
import sharp from "sharp";

import { ROOT, type Rectangle } from "./image.ts";

export interface OcrResult {
  text: string;
  confidence: number;
}

interface OcrRuntime {
  detSession: ort.InferenceSession;
  recSession: ort.InferenceSession;
  characters: string[];
}

const DET_MODEL_PATH = /* @__PURE__ */ resolve(ROOT, "assets/models/ppocrv5_mobile_det.onnx");
const REC_MODEL_PATH = /* @__PURE__ */ resolve(ROOT, "assets/models/ppocrv5_mobile_rec.onnx");
const REC_CONFIG_PATH = /* @__PURE__ */ resolve(ROOT, "assets/models/ppocrv5_mobile_rec.yml");

let runtimePromise: Promise<OcrRuntime> | undefined;

export async function recognizeText(image: Buffer): Promise<OcrResult> {
  const runtime = await getRuntime();
  const textRectangle = await detectText(runtime.detSession, image);
  const textImage = await sharp(image).extract(textRectangle).png().toBuffer();
  return recognizeDetectedText(runtime.recSession, textImage, runtime.characters);
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
      if (
        !Array.isArray(characters) ||
        !characters.every((character) => typeof character === "string")
      ) {
        throw new Error("character_dict was not found in recognition config");
      }

      return ["", ...characters, " "];
    });
}

async function detectText(session: ort.InferenceSession, image: Buffer): Promise<Rectangle> {
  const metadata = await sharp(image).metadata();
  if (!metadata.width || !metadata.height) throw new Error("invalid OCR image");

  const inputWidth = roundTo32(metadata.width);
  const inputHeight = roundTo32(metadata.height);
  const { data } = await sharp(image)
    .removeAlpha()
    .resize(inputWidth, inputHeight, { fit: "fill" })
    .raw()
    .toBuffer({ resolveWithObject: true });

  const output = (await session.run({ x: toDetTensor(data, inputWidth, inputHeight) }))
    .fetch_name_0;
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

async function recognizeDetectedText(
  session: ort.InferenceSession,
  image: Buffer,
  characters: string[],
): Promise<OcrResult> {
  const metadata = await sharp(image).metadata();
  if (!metadata.width || !metadata.height) throw new Error("invalid detected text image");

  const inputHeight = 48;
  const inputWidth = 320;
  const resizedWidth = Math.min(
    inputWidth,
    Math.max(1, Math.ceil((inputHeight * metadata.width) / metadata.height)),
  );
  const { data } = await sharp(image)
    .removeAlpha()
    .resize(resizedWidth, inputHeight, { fit: "fill" })
    .raw()
    .toBuffer({ resolveWithObject: true });

  const output = (
    await session.run({
      x: toRecTensor(data, resizedWidth, inputWidth, inputHeight),
    })
  ).fetch_name_0;
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

function toRecTensor(
  data: Buffer,
  resizedWidth: number,
  width: number,
  height: number,
): ort.Tensor {
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
