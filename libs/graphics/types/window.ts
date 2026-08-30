export type Window = {
  id: number;
  name: string;
  owner_name: string;
};

declare module "../src/addon/index.ts" {
  interface Addon {
    listWindows(): Window[];
  }
}
