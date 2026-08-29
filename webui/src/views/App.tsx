import { useEffect, useState } from "react";
import { cx } from "class-variance-authority";
import {
  HiOutlineArrowUpRight,
  HiOutlineBolt,
  HiOutlinePlay,
  HiOutlineStop,
} from "react-icons/hi2";
import { Button } from "@components/Button";
import { useAppStore } from "@stores/app";
import { connect } from "@stores/event";
import { start, stop, useTFTStore } from "@stores/tft";
import { useResolvedAppearance } from "@stores/preference";
import { BottomNavigator } from "./BottomNavigator";
import { InspectorPanel } from "./InspectorPanel";
import { Screenshot } from "./Screenshot";
import { SettingsPanel } from "./SettingsPanel";
import { StatePanel } from "./StatePanel";

export function App() {
  useEffect(() => connect(), []);
  const appearance = useResolvedAppearance();
  const activePanel = useAppStore((state) => state.activePanel);

  useEffect(() => {
    document.documentElement.dataset.appearance = appearance;
    document.documentElement.style.colorScheme = appearance;
  }, [appearance]);

  return (
    <main className="relative min-h-dvh overflow-hidden bg-white text-[#171717] dark:bg-[#050505] dark:text-[#ededed]">
      <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(rgba(0,0,0,0.04)_1px,transparent_1px),linear-gradient(90deg,rgba(0,0,0,0.04)_1px,transparent_1px)] bg-[size:48px_48px] [mask-image:linear-gradient(to_bottom,black,transparent_72%)] dark:bg-[linear-gradient(rgba(255,255,255,0.025)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.025)_1px,transparent_1px)]" />
      <section className="relative z-10 mx-auto flex min-h-dvh max-w-7xl flex-col px-5 pb-32 pt-6 sm:px-8 sm:pt-8">
        <AppHeader />

        <Screenshot />
      </section>

      <BottomNavigator />
      {activePanel === "inspector" && <InspectorPanel />}
      {activePanel === "settings" && <SettingsPanel />}
      {activePanel === "state" && <StatePanel />}
    </main>
  );
}

function AppHeader() {
  const tft = useTFTStore();
  const [pending, setPending] = useState(false);
  const isRunning = tft.status === "running";

  return (
    <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <div className="mb-2 flex items-center gap-2 text-[10px] font-medium uppercase tracking-[0.18em] text-black/40 dark:text-white/35">
          <HiOutlineBolt className="size-3.5" /> Session control
          <span
            className={cx(
              "ml-1 size-1.5 rounded-full",
              isRunning ? "bg-[#52a8ff] shadow-[0_0_8px_#52a8ff]" : "bg-black/25 dark:bg-white/25",
            )}
          />
          <span className="font-mono tracking-[0.12em]">{isRunning ? "Live" : "Standby"}</span>
        </div>
        <h1 className="text-balance text-[clamp(2rem,3vw,3rem)] font-semibold leading-none tracking-[-0.05em] text-[#171717] dark:text-white">
          Read the board. Make the move.
        </h1>
        <p className="mt-2 max-w-xl text-sm leading-5 text-black/40 dark:text-white/40">
          Capture and inspect the current TFT board.
        </p>
      </div>
      <div className="flex shrink-0 flex-wrap items-center gap-2">
        <Button
          disabled={pending}
          onClick={toggleService}
          variant={isRunning ? "outline" : "solid"}
          className={cx("group", "disabled:cursor-wait")}
        >
          {isRunning ? <HiOutlineStop className="size-4" /> : <HiOutlinePlay className="size-4" />}
          {pending ? "Updating…" : isRunning ? "Stop session" : "Start session"}
          {!isRunning && (
            <HiOutlineArrowUpRight className="ml-1 size-3.5 transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5" />
          )}
        </Button>
      </div>
    </div>
  );

  async function toggleService() {
    setPending(true);
    try {
      await (isRunning ? stop() : start());
    } finally {
      setPending(false);
    }
  }
}
