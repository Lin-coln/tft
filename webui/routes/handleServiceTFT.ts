import { start, stop, store } from "@services/tft/index.ts";
import type { TFTState } from "@shared/index.ts";

type Req = Bun.BunRequest<"/api/services/tft">;

const actions: TFTState.Actions = { start, stop };

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
      const handler = actions[body.name];
      try {
        const data = await handler.apply(null, body.args as any);
        return Response.json({ data });
      } catch (err) {
        return Response.json({ error: err instanceof Error ? err.message : String(err) }, 400);
      }
    }

    return Response.json(null, 404);
  },
};
