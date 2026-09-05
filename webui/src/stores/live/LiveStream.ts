export type FramePacket = {
  timestamp: number;
  duration?: number;
  keyframe: boolean;
  data: AllowSharedBufferSource;
};

export abstract class LiveStream<T> {
  #maxBufferSize: number;
  #config: VideoDecoderConfig;

  #buffer: FramePacket[] = [];
  #decoder: VideoDecoder;

  constructor(opts: { maxBufferSize?: number; config: VideoDecoderConfig }) {
    this.#maxBufferSize = opts.maxBufferSize ?? 3;
    this.#config = opts.config;

    this.#decoder = new VideoDecoder({
      output: (frame) => {
        this.onRender(frame);
      },
      error: (error) => {
        this.onError(error);
      },
    });

    this.#decoder.addEventListener("dequeue", () => {
      this.#consume();
    });

    this.#decoder.configure({
      ...this.#config,
      optimizeForLatency: true,
    });
  }

  abstract onResolvePacket(data: T): FramePacket;

  abstract onRender(frame: VideoFrame): void;

  abstract onError(error: unknown): void;

  // ws or other conn will call this to push packet data from remote
  public push(data: T): void {
    const packet = this.onResolvePacket(data);

    if (this.#buffer.length >= this.#maxBufferSize) {
      this.#buffer.shift();
    }

    this.#buffer.push(packet);

    this.#consume();
  }

  public close(): void {
    this.#buffer.length = 0;
    if (this.#decoder.state !== "closed") this.#decoder.close();
  }

  #consume(): void {
    if (this.#decoder.state !== "configured") {
      return;
    }

    while (this.#buffer.length > 0 && this.#decoder.decodeQueueSize < this.#maxBufferSize) {
      const packet = this.#buffer.shift()!;

      this.#decoder.decode(
        new EncodedVideoChunk({
          type: packet.keyframe ? "key" : "delta",
          timestamp: packet.timestamp,
          duration: packet.duration,
          data: packet.data,
        }),
      );
    }
  }
}
