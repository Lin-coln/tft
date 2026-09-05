import { handleEvents } from "./handleEvents.ts";
import { handleServiceTFT } from "./handleServiceTFT.ts";
import { handleLiveStream } from "./handleLiveStream.ts";

export const routes = {
  "/api/events": handleEvents,

  "/api/services/tft": handleServiceTFT,

  "/api/live_stream": handleLiveStream,
};
