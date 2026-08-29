import { handleEvents } from "./handleEvents.ts";

export const routes: Bun.Serve.Routes<void, string> = {
  "/api/events": handleEvents,
};
