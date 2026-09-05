const HEADER_SIZE = 13;

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

export function encodeLiveStreamPacket(packet: LiveStreamPacket): Uint8Array<ArrayBuffer> {
  const encoded = new Uint8Array(HEADER_SIZE + packet.data.byteLength);
  const view = new DataView(encoded.buffer);

  view.setUint8(0, packet.keyframe ? 1 : 0);
  view.setFloat64(1, packet.timestamp, true);
  view.setUint32(9, packet.duration, true);
  encoded.set(packet.data, HEADER_SIZE);

  return encoded;
}

export function decodeLiveStreamPacket(data: ArrayBuffer): LiveStreamPacket {
  if (data.byteLength <= HEADER_SIZE) {
    throw new Error("Received an invalid live stream packet");
  }

  const view = new DataView(data);

  return {
    keyframe: (view.getUint8(0) & 1) === 1,
    timestamp: view.getFloat64(1, true),
    duration: view.getUint32(9, true),
    data: new Uint8Array(data.slice(HEADER_SIZE)),
  };
}
