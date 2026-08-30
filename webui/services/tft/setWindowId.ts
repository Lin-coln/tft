import { store } from "./utils.ts";

export async function setWindowId(window_id: number) {
  store.setState({ window_id });
}
