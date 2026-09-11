import { subscribeStream } from "@services/tft/index.ts";
import { encodeLiveStreamConfig, encodeLiveStreamPacket } from "@shared/liveStream.ts";

type Req = Bun.BunRequest<"/api/live_stream">;

export type LiveStreamSocketData = {
  unsubscribe?: () => void;
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
    let activeConfig: Uint8Array | null = null;
    let waitingForKeyframe = true;
    socket.data.unsubscribe = subscribeStream((packet, streamConfig) => {
      const description = Uint8Array.from(streamConfig.data);
      if (!activeConfig || !equalBytes(activeConfig, description)) {
        socket.send(
          encodeLiveStreamConfig({
            width: streamConfig.width,
            height: streamConfig.height,
            description,
          }),
          false,
        );
        activeConfig = description;
        waitingForKeyframe = true;
      }

      if (waitingForKeyframe && !packet.keyframe) return;
      waitingForKeyframe = false;

      socket.send(
        encodeLiveStreamPacket({
          keyframe: packet.keyframe,
          timestamp: toMicroseconds(packet.pts, packet.timebaseNum, packet.timebaseDen),
          duration: toMicroseconds(packet.duration, packet.timebaseNum, packet.timebaseDen),
          data: Uint8Array.from(packet.data),
        }),
        false,
      );
    });
  },
  message() {},
  close(socket) {
    socket.data.unsubscribe?.();
    socket.data.unsubscribe = undefined;
  },
};

function toMicroseconds(value: bigint, timebaseNum: number, timebaseDen: number): number {
  return Number((value * BigInt(timebaseNum) * 1_000_000n) / BigInt(timebaseDen));
}

function equalBytes(a: Uint8Array, b: Uint8Array): boolean {
  if (a.byteLength !== b.byteLength) return false;
  for (let index = 0; index < a.byteLength; index += 1) {
    if (a[index] !== b[index]) return false;
  }
  return true;
}
