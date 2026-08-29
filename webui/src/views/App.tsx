import { useEffect, useId, useState } from "react";
import clsx from "clsx";
import {
  HiOutlineArrowUpRight,
  HiOutlineBolt,
  HiOutlineChartBar,
  HiOutlineHome,
  HiOutlinePlay,
  HiOutlineQueueList,
  HiOutlineCog6Tooth,
  HiOutlineSquare2Stack,
  HiOutlineStop,
} from "react-icons/hi2";
import { connect, useClientId } from "@stores/event";
import { start, stop, useTFTStore } from "@stores/tft";
import { useResolvedAppearance } from "@stores/preference";
import { Inspector } from "./Inspector";
import { Settings } from "./Settings";
import { State } from "./State";
import { Screenshot } from "./Screenshot";

const navigation = [
  { label: "Overview", icon: HiOutlineHome, active: true },
  { label: "Timeline", icon: HiOutlineChartBar },
  { label: "Snapshots", icon: HiOutlineSquare2Stack },
];

export function App() {
  useEffect(() => connect(), []);
  const clientId = useClientId();
  const tft = useTFTStore();
  const appearance = useResolvedAppearance();
  const [activePanel, setActivePanel] = useState<"inspector" | "settings" | "state" | null>(null);
  const [pending, setPending] = useState(false);
  const inspectorId = useId();
  const settingsId = useId();
  const stateId = useId();
  const isRunning = tft.status === "running";

  useEffect(() => {
    document.documentElement.dataset.appearance = appearance;
    document.documentElement.style.colorScheme = appearance;
  }, [appearance]);

  async function toggleService() {
    setPending(true);
    try {
      await (isRunning ? stop() : start());
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="relative min-h-dvh overflow-hidden bg-white text-[#171717] dark:bg-[#050505] dark:text-[#ededed]">
      <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(rgba(0,0,0,0.04)_1px,transparent_1px),linear-gradient(90deg,rgba(0,0,0,0.04)_1px,transparent_1px)] bg-[size:48px_48px] [mask-image:linear-gradient(to_bottom,black,transparent_72%)] dark:bg-[linear-gradient(rgba(255,255,255,0.025)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.025)_1px,transparent_1px)]" />
      <section className="relative z-10 mx-auto flex min-h-dvh max-w-7xl flex-col px-5 pb-32 pt-6 sm:px-8 sm:pt-8">
        <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <div className="mb-2 flex items-center gap-2 text-[10px] font-medium uppercase tracking-[0.18em] text-black/40 dark:text-white/35">
              <HiOutlineBolt className="size-3.5" /> Session control
              <span
                className={clsx(
                  "ml-1 size-1.5 rounded-full",
                  isRunning
                    ? "bg-[#52a8ff] shadow-[0_0_8px_#52a8ff]"
                    : "bg-black/25 dark:bg-white/25",
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
            <button
              type="button"
              disabled={pending}
              onClick={toggleService}
              className={clsx(
                "group inline-flex h-10 items-center gap-2 rounded-md px-4 text-[13px] font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/60 disabled:cursor-wait disabled:opacity-50 dark:focus-visible:ring-white/60",
                isRunning
                  ? "border border-black/10 bg-black/[0.04] text-[#171717] hover:bg-black/[0.08] dark:border-white/10 dark:bg-white/[0.04] dark:text-white dark:hover:bg-white/[0.08]"
                  : "bg-[#171717] text-white hover:bg-black/80 dark:bg-white dark:text-black dark:hover:bg-white/85",
              )}
            >
              {isRunning ? (
                <HiOutlineStop className="size-4" />
              ) : (
                <HiOutlinePlay className="size-4" />
              )}
              {pending ? "Updating…" : isRunning ? "Stop session" : "Start session"}
              {!isRunning && (
                <HiOutlineArrowUpRight className="ml-1 size-3.5 transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5" />
              )}
            </button>
          </div>
        </div>

        <Screenshot />
      </section>

      <div className="fixed inset-x-0 bottom-5 z-40 flex justify-center px-4 sm:bottom-7">
        <nav
          aria-label="Primary navigation"
          className="flex h-12 items-center gap-1 rounded-xl border border-black/15 bg-white/95 p-1 shadow-[0_16px_48px_rgba(0,0,0,0.14)] backdrop-blur-xl dark:border-white/15 dark:bg-[#0a0a0a]/95 dark:shadow-[0_16px_48px_rgba(0,0,0,0.65)]"
        >
          {navigation.map(({ label, icon: Icon, active }) => (
            <button
              key={label}
              type="button"
              aria-label={label}
              className={clsx(
                "grid size-9 place-items-center rounded-lg transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/50 dark:focus-visible:ring-white/50",
                active
                  ? "bg-black/10 text-[#171717] dark:bg-white/10 dark:text-white"
                  : "text-black/40 hover:bg-black/[0.06] hover:text-black/75 dark:text-white/35 dark:hover:bg-white/[0.06] dark:hover:text-white/75",
              )}
            >
              <Icon className="size-[17px]" />
            </button>
          ))}
          <div className="mx-1 h-5 w-px bg-black/10 dark:bg-white/10" />
          <button
            type="button"
            aria-label="Toggle state"
            aria-expanded={activePanel === "state"}
            aria-controls={stateId}
            onClick={() => setActivePanel((panel) => (panel === "state" ? null : "state"))}
            className={clsx(
              "flex h-9 items-center gap-2 rounded-lg px-3 text-xs font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/50 dark:focus-visible:ring-white/50",
              activePanel === "state"
                ? "bg-[#171717] text-white dark:bg-white dark:text-black"
                : "text-black/60 hover:bg-black/[0.06] hover:text-black dark:text-white/60 dark:hover:bg-white/[0.06] dark:hover:text-white",
            )}
          >
            <HiOutlineSquare2Stack className="size-[17px]" />
            <span>State</span>
          </button>
          <button
            type="button"
            aria-label="Toggle inspector"
            aria-expanded={activePanel === "inspector"}
            aria-controls={inspectorId}
            onClick={() => setActivePanel((panel) => (panel === "inspector" ? null : "inspector"))}
            className={clsx(
              "flex h-9 items-center gap-2 rounded-lg px-3 text-xs font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/50 dark:focus-visible:ring-white/50",
              activePanel === "inspector"
                ? "bg-[#171717] text-white dark:bg-white dark:text-black"
                : "text-black/60 hover:bg-black/[0.06] hover:text-black dark:text-white/60 dark:hover:bg-white/[0.06] dark:hover:text-white",
            )}
          >
            <HiOutlineQueueList className="size-[17px]" />
            <span>Inspector</span>
          </button>
          <button
            type="button"
            aria-label="Toggle settings"
            aria-expanded={activePanel === "settings"}
            aria-controls={settingsId}
            onClick={() => setActivePanel((panel) => (panel === "settings" ? null : "settings"))}
            className={clsx(
              "grid size-9 place-items-center rounded-lg transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/50 dark:focus-visible:ring-white/50",
              activePanel === "settings"
                ? "bg-[#171717] text-white dark:bg-white dark:text-black"
                : "text-black/40 hover:bg-black/[0.06] hover:text-black/75 dark:text-white/35 dark:hover:bg-white/[0.06] dark:hover:text-white/75",
            )}
          >
            <HiOutlineCog6Tooth className="size-[17px]" />
          </button>
        </nav>
      </div>

      {activePanel === "inspector" && (
        <Inspector
          id={inspectorId}
          onClose={() => setActivePanel(null)}
          clientId={clientId}
          state={tft}
        />
      )}
      {activePanel === "settings" && (
        <Settings id={settingsId} onClose={() => setActivePanel(null)} />
      )}
      {activePanel === "state" && (
        <State id={stateId} onClose={() => setActivePanel(null)} state={tft} />
      )}
    </main>
  );
}
