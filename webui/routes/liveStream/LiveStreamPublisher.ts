import { config, encodeLiveStreamPacket } from "@shared/liveStream.ts";

type FrameTiming = {
  timestamp: number;
  duration: number;
};

export type StreamPublisher = {
  send(frame: { data: Uint8Array<ArrayBuffer>; keyframe: boolean }): void;
  close(): void;
};

type StreamPublisherOptions<T> = {
  socket: Bun.ServerWebSocket<T>;
  onPublish(): void;
};

export function createStreamPublisher<T>({
  socket,
  onPublish,
}: StreamPublisherOptions<T>): StreamPublisher {
  let frameIndex = 0;
  const timings: FrameTiming[] = [];
  let closed = false;

  const timer = setInterval(publish, 1_000 / config.fps);

  return {
    send(frame) {
      const timing = timings.shift();
      if (!timing || closed) return;

      socket.send(
        encodeLiveStreamPacket({
          keyframe: frame.keyframe,
          timestamp: timing.timestamp,
          duration: timing.duration,
          data: frame.data,
        }),
        false,
      );
    },
    close() {
      if (closed) return;
      closed = true;
      clearInterval(timer);
    },
  };

  function publish(): void {
    if (closed) return;

    const timestamp = Math.floor((frameIndex * 1_000_000) / config.fps);
    const nextTimestamp = Math.floor(((frameIndex + 1) * 1_000_000) / config.fps);
    timings.push({ timestamp, duration: nextTimestamp - timestamp });
    frameIndex += 1;
    onPublish();
  }
}
