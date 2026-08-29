import { createStreamPromise } from "./createStreamPromise.ts";
import { uuid } from "./uuid.ts";
import { create } from "zustand";
import { useEffect } from "react";

type WebUIEvents = {};

const store = create<{
  clientId: string;
  streamPromise: (Promise<void> & { dispose: () => void }) | null;
  listeners: Set<(event: WebUIEvents) => void>;
}>(() => ({
  clientId: uuid(),
  streamPromise: null,
  listeners: new Set(),
}));

export const useEventStore = store;

export function useEvents(cb: (event: WebUIEvents) => void) {
  useEffect(() => subscribe(cb), []);
}

export function subscribe(cb: (event: WebUIEvents) => void) {
  store.getState().listeners.add(cb);
  return (): void => void store.getState().listeners.delete(cb);
}

export function connect() {
  store.getState().streamPromise?.dispose();

  const streamPromise = createStreamPromise({
    onEvent(event) {
      for (const cb of store.getState().listeners) cb(event as WebUIEvents);
    },
    onDispose() {
      store.setState({ streamPromise: null });
    },
    handleReconnect: connect,
    async handleRequest(signal) {
      const resp = await fetch("/api/events", {
        signal,
        headers: {
          "x-client-id": store.getState().clientId,
        },
      });
      if (!resp.ok) {
        throw new Error(`Failed to fetch - ${resp.status} ${resp.statusText}`);
      }
      return resp;
    },
  });

  store.setState({ streamPromise });

  return () => {
    store.getState().streamPromise?.dispose();
  };
}
