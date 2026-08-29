export function createHMR<T>(name: string, generate: () => T): () => T {
  return () => {
    const syb = Symbol.for("utils:__HMR__");
    const global = globalThis as typeof globalThis & Record<symbol, Record<string, any>>;
    const HMR = (global[syb] ??= {});
    return (HMR[name] ??= generate());
  };
}
