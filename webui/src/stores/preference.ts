import { useState, useEffect } from "react";
import { create } from "zustand";

type Appearance = "auto" | "dark" | "light";
type ResolvedAppearance = Exclude<Appearance, "auto">;

const store = create<{
  appearance: Appearance;
}>((_set, _get, api) => {
  api.subscribe((s) => {
    localStorage.setItem("tft.pref.appearance", s.appearance);
  });
  return {
    appearance: (localStorage.getItem("tft.pref.appearance") as Appearance) ?? "auto",
  };
});

export const usePreferenceStore = store;

export function setAppearance(appearance: Appearance) {
  store.setState({ appearance });
}

export function useResolvedAppearance(): ResolvedAppearance {
  const appearance = store((state) => state.appearance);

  const [system, setSystem] = useState(() => getSystemAppearance());

  useEffect(() => {
    if (appearance !== "auto") return;
    const media = window.matchMedia("(prefers-color-scheme: dark)");
    const onChange = () => setSystem(getSystemAppearance());
    media.addEventListener("change", onChange);
    return () => media.removeEventListener("change", onChange);
  }, [appearance]);

  return appearance === "auto" ? system : appearance;
}

function getSystemAppearance(): ResolvedAppearance {
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}
