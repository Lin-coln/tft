import { routes as backendRoutes } from "./routes";
import Pages from "./src/index.html";

const server = Bun.serve({
  port: 3000,
  development: { hmr: true, console: true },
  routes: {
    ...backendRoutes,
    "/*": Pages,
  },
});

console.log(`listening ${server.url.toString()}`);
