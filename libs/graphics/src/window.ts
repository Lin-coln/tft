import { create, pick } from "./addon.ts";

export type Window = {
  id: number;
  name: string;
  owner_name: string;
};

export type StreamConfig = {
  data: Uint8Array;
  size: number;
  width: number;
  height: number;
  nalLengthSize: number;
};

export type StreamPacket = {
  data: Uint8Array;
  size: number;
  pts: bigint;
  duration: bigint;
  timebaseNum: number;
  timebaseDen: number;
  frameCount: number;
  keyframe: boolean;
};

export interface Runtime {
  getTarget(): number | null;
  getStreamConfig(): StreamConfig | null;
  updateTarget(windowId: number): void;
  screenshot(): Uint8Array;
}

declare module "./addon.ts" {
  interface Addon {
    listWindows(): Window[];
    Runtime: new (handleStreamOutput?: (packet: StreamPacket) => void) => Runtime;
  }
}

export const listWindows = /* @__PURE__ */ pick((x) => x.listWindows);

export const Runtime = /* @__PURE__ */ create((get) => get().Runtime);
