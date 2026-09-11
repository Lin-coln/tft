const CONFIG_HEADER_SIZE = 9;
const PACKET_HEADER_SIZE = 14;

const MESSAGE_CONFIG = 0;
const MESSAGE_PACKET = 1;

export const config = {
  codec: "avc1.64001F",
  profile: "high",
  level: "3.1",
  width: 854,
  height: 480,
  fps: 60,
  pixelFormat: "bgra",
  bitrate: 4_000_000,
  maxBitrate: 6_000_000,
  bufferSize: 4_000_000,
};

export type LiveStreamPacket = {
  keyframe: boolean;
  timestamp: number;
  duration: number;
  data: Uint8Array<ArrayBuffer>;
};

export type LiveStreamConfig = {
  width: number;
  height: number;
  description: Uint8Array<ArrayBuffer>;
};

export type LiveStreamMessage =
  | { type: "config"; config: LiveStreamConfig }
  | { type: "packet"; packet: LiveStreamPacket };

export function encodeLiveStreamConfig(streamConfig: LiveStreamConfig): Uint8Array<ArrayBuffer> {
  const encoded = new Uint8Array(CONFIG_HEADER_SIZE + streamConfig.description.byteLength);
  const view = new DataView(encoded.buffer);

  view.setUint8(0, MESSAGE_CONFIG);
  view.setUint32(1, streamConfig.width, true);
  view.setUint32(5, streamConfig.height, true);
  encoded.set(streamConfig.description, CONFIG_HEADER_SIZE);
  return encoded;
}

export function encodeLiveStreamPacket(packet: LiveStreamPacket): Uint8Array<ArrayBuffer> {
  const encoded = new Uint8Array(PACKET_HEADER_SIZE + packet.data.byteLength);
  const view = new DataView(encoded.buffer);

  view.setUint8(0, MESSAGE_PACKET);
  view.setUint8(1, packet.keyframe ? 1 : 0);
  view.setFloat64(2, packet.timestamp, true);
  view.setUint32(10, packet.duration, true);
  encoded.set(packet.data, PACKET_HEADER_SIZE);

  return encoded;
}

export function decodeLiveStreamMessage(data: ArrayBuffer): LiveStreamMessage {
  const view = new DataView(data);
  const type = view.getUint8(0);

  if (type === MESSAGE_CONFIG) {
    if (data.byteLength <= CONFIG_HEADER_SIZE) {
      throw new Error("Received an invalid live stream config");
    }
    return {
      type: "config",
      config: {
        width: view.getUint32(1, true),
        height: view.getUint32(5, true),
        description: new Uint8Array(data.slice(CONFIG_HEADER_SIZE)),
      },
    };
  }

  if (type !== MESSAGE_PACKET || data.byteLength <= PACKET_HEADER_SIZE) {
    throw new Error("Received an invalid live stream packet");
  }

  return {
    type: "packet",
    packet: {
      keyframe: (view.getUint8(1) & 1) === 1,
      timestamp: view.getFloat64(2, true),
      duration: view.getUint32(10, true),
      data: new Uint8Array(data.slice(PACKET_HEADER_SIZE)),
    },
  };
}
