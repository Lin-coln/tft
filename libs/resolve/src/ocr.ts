import * as ort from "onnxruntime-node";
import { resolve } from "node:path";
import sharp from "sharp";

import { ROOT } from "./image.ts";

const DET_MODEL_PATH = /* @__PURE__ */ resolve(ROOT, "assets/models/ppocrv5_mobile_det.onnx");
const REC_MODEL_PATH = /* @__PURE__ */ resolve(ROOT, "assets/models/ppocrv5_mobile_rec.onnx");
const REC_CONFIG_PATH = /* @__PURE__ */ resolve(ROOT, "assets/models/ppocrv5_mobile_rec.yml");

let runtime: Awaited<ReturnType<typeof createRuntime>> | undefined;

export async function recognizeText(image: Buffer): Promise<{ text: string; confidence: number }> {
  runtime ??= await createRuntime();
  const textImage = await detectText(image, runtime.detSession);
  return recognizeDetectedText(textImage, runtime.recSession, runtime.characters);
}

async function createRuntime() {
  const [detSession, recSession, yaml] = await Promise.all([
    ort.InferenceSession.create(DET_MODEL_PATH, { logSeverityLevel: 3 }),
    ort.InferenceSession.create(REC_MODEL_PATH, { logSeverityLevel: 3 }),
    Bun.file(REC_CONFIG_PATH).text(),
  ]);
  const config = Bun.YAML.parse(yaml) as {
    PostProcess?: { character_dict?: unknown };
  };
  const characterDict = config.PostProcess?.character_dict;
  if (
    !Array.isArray(characterDict) ||
    !characterDict.every((character) => typeof character === "string")
  ) {
    throw new Error("character_dict was not found in recognition config");
  }

  return {
    detSession,
    recSession,
    characters: ["", ...characterDict, " "],
  };
}

async function detectText(image: Buffer, session: ort.InferenceSession): Promise<Buffer> {
  const metadata = await sharp(image).metadata();
  if (!metadata.width || !metadata.height) throw new Error("invalid OCR image");

  const inputWidth = Math.max(32, Math.round(metadata.width / 32) * 32);
  const inputHeight = Math.max(32, Math.round(metadata.height / 32) * 32);
  const { data: pixels } = await sharp(image)
    .removeAlpha()
    .resize(inputWidth, inputHeight, { fit: "fill" })
    .raw()
    .toBuffer({ resolveWithObject: true });

  const plane = inputWidth * inputHeight;
  const tensor = new Float32Array(plane * 3);
  const mean = [0.485, 0.456, 0.406];
  const std = [0.229, 0.224, 0.225];
  for (let pixel = 0; pixel < plane; pixel++) {
    for (let channel = 0; channel < 3; channel++) {
      const bgr = pixels[pixel * 3 + (2 - channel)] ?? 0;
      tensor[channel * plane + pixel] = (bgr / 255 - mean[channel]!) / std[channel]!;
    }
  }

  const output = (
    await session.run({
      x: new ort.Tensor("float32", tensor, [1, 3, inputHeight, inputWidth]),
    })
  ).fetch_name_0;
  if (!output) throw new Error("detection model returned no output");

  const probabilities = output.data as Float32Array;
  const [, , outputHeight, outputWidth] = output.dims;
  if (!outputWidth || !outputHeight) {
    throw new Error("invalid detection model output shape");
  }

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

  if (maxX < minX || maxY < minY) return sharp(image).png().toBuffer();

  const scaleX = metadata.width / outputWidth;
  const scaleY = metadata.height / outputHeight;
  const left = Math.max(0, Math.floor(minX * scaleX) - 2);
  const top = Math.max(0, Math.floor(minY * scaleY) - 2);
  const right = Math.min(metadata.width, Math.ceil((maxX + 1) * scaleX) + 2);
  const bottom = Math.min(metadata.height, Math.ceil((maxY + 1) * scaleY) + 2);

  return sharp(image)
    .extract({ left, top, width: right - left, height: bottom - top })
    .png()
    .toBuffer();
}

async function recognizeDetectedText(
  image: Buffer,
  session: ort.InferenceSession,
  characters: string[],
): Promise<{ text: string; confidence: number }> {
  const metadata = await sharp(image).metadata();
  if (!metadata.width || !metadata.height) {
    throw new Error("invalid detected text image");
  }

  const inputHeight = 48;
  const inputWidth = 320;
  const resizedWidth = Math.min(
    inputWidth,
    Math.max(1, Math.ceil((inputHeight * metadata.width) / metadata.height)),
  );
  const { data: pixels } = await sharp(image)
    .removeAlpha()
    .resize(resizedWidth, inputHeight, { fit: "fill" })
    .raw()
    .toBuffer({ resolveWithObject: true });

  const plane = inputWidth * inputHeight;
  const tensor = new Float32Array(plane * 3);
  for (let y = 0; y < inputHeight; y++) {
    for (let x = 0; x < resizedWidth; x++) {
      const source = (y * resizedWidth + x) * 3;
      const target = y * inputWidth + x;
      for (let channel = 0; channel < 3; channel++) {
        const bgr = pixels[source + (2 - channel)] ?? 0;
        tensor[channel * plane + target] = bgr / 127.5 - 1;
      }
    }
  }

  const output = (
    await session.run({
      x: new ort.Tensor("float32", tensor, [1, 3, inputHeight, inputWidth]),
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
