import { screenshot, start, stop, store } from "@services/tft/index.ts";
import type { TFTState } from "@shared/index.ts";

type Req = Bun.BunRequest<"/api/services/tft">;

const actions: TFTState.Actions = { screenshot, start, stop };

export const handleServiceTFT = {
  GET(req: Req) {
    return Response.json(store.getState());
  },
  async POST(req: Req) {
    const body = (await req.json()) as {
      type: "invoke";
      name: keyof TFTState.Actions;
      args: any[];
    };

    if (body.name in actions) {
      const handler = actions[body.name] as (...args: any[]) => Promise<unknown>;
      try {
        const data = await handler.apply(null, body.args as any);

        const u8arr = resolveUint8Array(data);
        if (u8arr) {
          return new Response(u8arr, {
            headers: { "Content-Type": "application/octet-stream" },
          });
        }

        return Response.json({ data });
      } catch (err) {
        return Response.json({ error: err instanceof Error ? err.message : String(err) }, 400);
      }
    }

    return Response.json(null, 404);
  },
};

function resolveUint8Array(data: unknown): Blob | ArrayBuffer | null {
  if (data instanceof Blob || data instanceof ArrayBuffer) return data;

  if (ArrayBuffer.isView(data)) {
    return new Uint8Array(data.buffer, data.byteOffset, data.byteLength).slice().buffer;
  }

  return null;
}
