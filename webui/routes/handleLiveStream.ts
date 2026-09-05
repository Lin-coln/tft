import { createH264Encoder, type H264Encoder } from "./liveStream/H264Encoder.ts";
import { createStreamPublisher, type StreamPublisher } from "./liveStream/LiveStreamPublisher.ts";
import { config } from "@shared/liveStream.ts";

type Req = Bun.BunRequest<"/api/live_stream">;

export type LiveStreamSocketData = {
  encoder?: H264Encoder;
  stream?: StreamPublisher;
};

export const handleLiveStream = {
  GET(req: Req, server: Bun.Server<LiveStreamSocketData>) {
    const upgraded = server.upgrade(req, { data: {} });

    if (upgraded) return;

    return new Response("Expected a WebSocket upgrade", { status: 426 });
  },
};

export const liveStreamWebSocket: Bun.WebSocketHandler<LiveStreamSocketData> = {
  data: {} as LiveStreamSocketData,
  open(socket) {
    const encoder = createH264Encoder((data) => {
      stream.send(data);
    });
    const stream = createStreamPublisher({
      socket,
      onPublish() {
        encoder.encode(encodeFrameFromRate());
      },
    });

    socket.data.encoder = encoder;
    socket.data.stream = stream;
  },
  message() {},
  close(socket) {
    socket.data.encoder?.close();
    socket.data.stream?.close();
    socket.data.encoder = undefined;
    socket.data.stream = undefined;
  },
};

function encodeFrameFromRate(): Uint8Array<ArrayBuffer> {
  const rate = (Date.now() % 1_000) / 1_000;
  const gray = Math.round(rate * 255);
  const frame = new Uint8Array(config.width * config.height * 4);
  const pixels = new Uint32Array(frame.buffer);
  pixels.fill((0xff << 24) | (gray << 16) | (gray << 8) | gray);
  return frame;
}
