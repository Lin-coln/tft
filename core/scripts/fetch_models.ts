import { mkdir } from "node:fs/promises";
import { join } from "node:path";

const HOST = "https://hf-mirror.com/PaddlePaddle";

const MODELS_DIR = join(import.meta.dir, "..", "assets", "models");

const MODELS = {
  det: "PP-OCRv5_mobile_det_onnx",
  rec: "PP-OCRv5_mobile_rec_onnx",
} as const;

await main();

async function main() {
  await mkdir(MODELS_DIR, { recursive: true });

  await downloadModel(MODELS.det, "ppocrv5_mobile_det");
  await downloadModel(MODELS.rec, "ppocrv5_mobile_rec");
}

async function downloadModel(repo: string, name: string) {
  await download(
    `${HOST}/${repo}/resolve/main/inference.onnx?download=true`,
    join(MODELS_DIR, `${name}.onnx`),
  );

  await download(
    `${HOST}/${repo}/resolve/main/inference.yml?download=true`,
    join(MODELS_DIR, `${name}.yml`),
  );
}

async function download(url: string, filename: string) {
  console.log(`↓ ${url}`);

  const response = await fetch(url);

  if (!response.ok) {
    throw new Error(`Failed to download: ${response.status} ${response.statusText}`);
  }

  await Bun.write(filename, response);

  console.log(`✓ ${filename}`);
}
