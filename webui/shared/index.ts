import type { Window } from "@tft/graphics";

export type ServerEvent = { comment: string } | { event: string; data: any };

export type TFTState = {
  status: "idle" | "running";
  window_id: number;
  level: {
    current: number;
    confidence: number;
    experience: {
      current: number;
      required: number;
      confidence: number;
    };
  };
  currency: { current: number; confidence: number };
  shop: {
    slot: number;
    name: string;
    confidence: number;
  }[];
};

export namespace TFTState {
  export interface Actions {
    start(): Promise<void>;
    stop(): Promise<void>;
    screenshot(): Promise<Uint8Array>;
    listWindows(): Promise<Window[]>;
    setWindowId(window_id: number): Promise<void>;
  }
}
