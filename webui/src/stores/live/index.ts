import { config, decodeLiveStreamPacket } from "@shared/liveStream.ts";
import { LiveStream, type FramePacket } from "./LiveStream.ts";

export type StreamStatus = "connecting" | "connected" | "disconnected";

type StreamHandlers = {
  onFrame(frame: VideoFrame): void;
  onError(error: unknown): void;
  onStatus(status: StreamStatus): void;
};

export class Stream extends LiveStream<ArrayBuffer> {
  #handlers: StreamHandlers;
  #socket: WebSocket | null = null;

  constructor(handlers: StreamHandlers) {
    if (!("VideoDecoder" in window)) {
      throw new Error("This browser does not support WebCodecs video decoding");
    }

    super({
      config: {
        codec: config.codec,
        codedWidth: config.width,
        codedHeight: config.height,
      },
    });
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
        this.push(event.data);
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

  override onResolvePacket(data: ArrayBuffer): FramePacket {
    return decodeLiveStreamPacket(data);
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
