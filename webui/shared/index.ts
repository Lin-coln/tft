export type ServerEvent = { comment: string } | { event: string; data: any };

export type TFTState = {
  status: "idle" | "running";
};

export namespace TFTState {
  export interface Actions {
    start(): Promise<void>;
    stop(): Promise<void>;
    screenshot(): Promise<Uint8Array>;
  }
}
