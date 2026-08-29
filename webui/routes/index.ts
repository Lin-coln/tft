import { handleEvents } from "./handleEvents.ts";
import { handleServiceTFT } from "./handleServiceTFT.ts";

export const routes: Bun.Serve.Routes<void, string> = {
  "/api/events": handleEvents,

  "/api/services/tft": handleServiceTFT,
};
