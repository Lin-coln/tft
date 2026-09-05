import { config } from "@shared/liveStream.ts";

export type H264Encoder = {
  encode(frame: Uint8Array<ArrayBuffer>): void;
  close(): void;
};

export type H264Frame = {
  data: Uint8Array<ArrayBuffer>;
  keyframe: boolean;
};

export type H264FrameHandler = (frame: H264Frame) => void;

export function createH264Encoder(frameHandler: H264FrameHandler): H264Encoder {
  const process = createFfmpegProcess();
  const frameByteLength = config.width * config.height * 4;
  let encoded = new Uint8Array(0);
  let closed = false;

  void (async () => {
    const reader = process.stdout.getReader();

    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        if (closed) continue;

        const next = new Uint8Array(encoded.byteLength + value.byteLength);
        next.set(encoded);
        next.set(value, encoded.byteLength);
        encoded = next;
        emitCompleteAccessUnits();
      }
    } catch (error) {
      if (!closed) console.error("H.264 encoder failed", error);
    } finally {
      reader.releaseLock();
    }
  })();

  return {
    encode(frame) {
      if (closed) return;
      if (frame.byteLength !== frameByteLength) {
        throw new Error(
          `Expected a ${frameByteLength}-byte BGRA frame, received ${frame.byteLength} bytes`,
        );
      }

      try {
        process.stdin.write(frame);
        process.stdin.flush();
      } catch (error) {
        closed = true;
        process.kill();
        console.error("Failed to write a frame to the H.264 encoder", error);
      }
    },
    close() {
      if (closed) return;
      closed = true;
      process.stdin.end();
      const killTimer = setTimeout(() => process.kill(), 1_000);
      void process.exited.finally(() => clearTimeout(killTimer));
    },
  };

  function emitCompleteAccessUnits(): void {
    while (true) {
      const first = findAccessUnitDelimiter(encoded, 0);
      if (first < 0) return;

      const second = findAccessUnitDelimiter(encoded, first + 5);
      if (second < 0) {
        if (first > 0) encoded = encoded.slice(first);
        return;
      }

      const accessUnit = encoded.slice(0, second);
      encoded = encoded.slice(second);
      frameHandler({
        data: accessUnit,
        keyframe: containsNalUnit(accessUnit, 5),
      });
    }
  }
}

function createFfmpegProcess() {
  return Bun.spawn(
    [
      "ffmpeg",
      "-hide_banner",
      "-loglevel",
      "error",
      "-f",
      "rawvideo",
      "-pixel_format",
      config.pixelFormat,
      "-video_size",
      `${config.width}x${config.height}`,
      "-framerate",
      String(config.fps),
      "-i",
      "pipe:0",
      "-an",
      "-c:v",
      "h264_videotoolbox",
      "-profile:v",
      config.profile,
      "-level:v",
      config.level,
      "-coder",
      "cabac",
      "-realtime",
      "1",
      "-prio_speed",
      "1",
      "-pix_fmt",
      "nv12",
      "-b:v",
      String(config.bitrate),
      "-maxrate",
      String(config.maxBitrate),
      "-bufsize",
      String(config.bufferSize),
      "-g",
      String(config.fps),
      "-bf",
      "0",
      "-sc_threshold",
      "0",
      "-color_range",
      "tv",
      "-colorspace",
      "bt709",
      "-color_primaries",
      "bt709",
      "-color_trc",
      "bt709",
      "-bsf:v",
      "h264_metadata=aud=insert:video_full_range_flag=0:colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1,dump_extra=freq=keyframe",
      "-f",
      "h264",
      "-flush_packets",
      "1",
      "pipe:1",
    ],
    { stdin: "pipe", stdout: "pipe", stderr: "inherit" },
  );
}

function containsNalUnit(data: Uint8Array, type: number): boolean {
  for (let index = 0; index <= data.byteLength - 4; index += 1) {
    const threeByteStartCode = data[index] === 0 && data[index + 1] === 0 && data[index + 2] === 1;
    const fourByteStartCode =
      data[index] === 0 && data[index + 1] === 0 && data[index + 2] === 0 && data[index + 3] === 1;

    if (threeByteStartCode && (data[index + 3]! & 0x1f) === type) return true;
    if (fourByteStartCode && (data[index + 4]! & 0x1f) === type) return true;
  }

  return false;
}

function findAccessUnitDelimiter(data: Uint8Array, offset: number): number {
  for (let index = offset; index <= data.byteLength - 5; index += 1) {
    const fourByteStartCode =
      data[index] === 0 && data[index + 1] === 0 && data[index + 2] === 0 && data[index + 3] === 1;

    if (fourByteStartCode && (data[index + 4]! & 0x1f) === 9) return index;

    const threeByteStartCode = data[index] === 0 && data[index + 1] === 0 && data[index + 2] === 1;

    if (threeByteStartCode && (data[index + 3]! & 0x1f) === 9) return index;
  }

  return -1;
}
