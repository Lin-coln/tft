import { decodeLiveStreamMessage } from "@shared/liveStream.ts";
import { LiveStream, type FramePacket } from "./LiveStream.ts";

export type StreamStatus = "connecting" | "connected" | "disconnected";

type StreamHandlers = {
  onFrame(frame: VideoFrame): void;
  onConfig(config: { width: number; height: number }): void;
  onError(error: unknown): void;
  onStatus(status: StreamStatus): void;
};

export class Stream extends LiveStream<FramePacket> {
  #handlers: StreamHandlers;
  #socket: WebSocket | null = null;

  constructor(handlers: StreamHandlers) {
    if (!("VideoDecoder" in window)) {
      throw new Error("This browser does not support WebCodecs video decoding");
    }

    super({});
    this.#handlers = handlers;
  }

  connect(): void {
    if (this.#socket) return;

    this.#handlers.onStatus("connecting");
    const protocol = location.protocol === "https:" ? "wss:" : "ws:";
    const socket = new WebSocket(`${protocol}//${location.host}/api/live_stream`);
    socket.binaryType = "arraybuffer";

    socket.addEventListener("open", () => this.#handlers.onStatus("connected"));
    socket.addEventListener("message", (event: MessageEvent<ArrayBuffer>) => {
      try {
        const message = decodeLiveStreamMessage(event.data);
        if (message.type === "config") {
          const { description, width, height } = message.config;
          this.configure({
            codec: resolveAvcCodec(description),
            codedWidth: width,
            codedHeight: height,
            description,
          });
          this.#handlers.onConfig({ width, height });
        } else {
          this.push(message.packet);
        }
      } catch (error) {
        this.#handlers.onError(error);
      }
    });
    socket.addEventListener("error", () => {
      this.#handlers.onError(new Error("Live stream WebSocket connection failed"));
    });
    socket.addEventListener("close", () => this.#handlers.onStatus("disconnected"));

    this.#socket = socket;
  }

  override onResolvePacket(packet: FramePacket): FramePacket {
    return packet;
  }

  override onRender(frame: VideoFrame): void {
    this.#handlers.onFrame(frame);
  }

  override onError(error: unknown): void {
    this.#handlers.onError(error);
  }

  override close(): void {
    this.#socket?.close();
    this.#socket = null;
    super.close();
  }
}

function resolveAvcCodec(description: Uint8Array): string {
  if (description.byteLength < 4 || description[0] !== 1) {
    throw new Error("Received an invalid AVCDecoderConfigurationRecord");
  }

  return `avc1.${[description[1], description[2], description[3]]
    .map((value) => value!.toString(16).padStart(2, "0"))
    .join("")}`;
}
