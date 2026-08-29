import { store } from "./utils.ts";

export { store } from "./utils.ts";

export { screenshot } from "./screenshot.ts";

export async function start() {
  if (store.getState().status === "running") return;
  store.setState({ status: "running" });
}

export async function stop() {
  if (store.getState().status === "idle") return;
  store.setState({ status: "idle" });
}
