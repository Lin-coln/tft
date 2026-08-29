import type { TFTState } from "@shared/index.ts";

export function toAction<K extends keyof TFTState.Actions>(name: K): TFTState.Actions[K] {
  return (...args: any[]) => invoke(name, args);
}

export async function invoke(name: string, args: any[]) {
  const resp = await fetch("/api/services/tft", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ type: "invoke", name, args }),
  });

  if (!resp.ok) {
    throw new Error(`Failed to fetch - ${resp.status} ${resp.statusText}`);
  }

  const result = await resp.json();

  if ("error" in result) {
    throw new Error(result.error);
  }

  return result.data;
}
