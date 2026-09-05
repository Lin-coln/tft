import { routes as backendRoutes } from "./routes";
import { liveStreamWebSocket, type LiveStreamSocketData } from "./routes/handleLiveStream.ts";
import Pages from "./src/index.html";

const server = Bun.serve<LiveStreamSocketData>({
  port: 3000,
  development: { hmr: true, console: true },
  websocket: liveStreamWebSocket,
  routes: {
    ...backendRoutes,
    "/*": Pages,
  },
});

console.log(`listening ${server.url.toString()}`);
