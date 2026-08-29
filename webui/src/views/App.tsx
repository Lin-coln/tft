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
  const [activePanel, setActivePanel] = useState<"inspector" | "settings" | null>(null);
  const [pending, setPending] = useState(false);
  const inspectorId = useId();
  const settingsId = useId();
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
      <header className="relative z-10 flex h-16 items-center justify-between border-b border-black/10 px-5 dark:border-white/10 sm:px-8">
        <div className="flex items-center gap-3">
          <div className="grid size-7 place-items-center rounded-md border border-black/15 bg-[#171717] text-[11px] font-black tracking-[-0.08em] text-white dark:border-white/15 dark:bg-white dark:text-black">
            TF
          </div>
          <div className="h-4 w-px bg-black/10 dark:bg-white/10" />
          <span className="text-[13px] font-medium text-black/65 dark:text-white/65">
            Match workspace
          </span>
        </div>
        <div className="flex items-center gap-2 font-mono text-[10px] uppercase tracking-[0.14em] text-black/40 dark:text-white/35">
          <span
            className={clsx(
              "size-1.5 rounded-full",
              isRunning ? "bg-[#52a8ff] shadow-[0_0_8px_#52a8ff]" : "bg-black/25 dark:bg-white/25",
            )}
          />
          {isRunning ? "Live" : "Standby"}
        </div>
      </header>

      <section className="relative z-10 mx-auto flex min-h-[calc(100dvh-4rem)] max-w-6xl flex-col justify-between px-5 pb-32 pt-16 sm:px-8 sm:pt-24">
        <div>
          <div className="mb-8 flex items-center gap-2 text-[11px] font-medium uppercase tracking-[0.18em] text-black/40 dark:text-white/35">
            <HiOutlineBolt className="size-3.5" /> Session control
          </div>
          <h1 className="max-w-3xl text-balance text-[clamp(2.8rem,7vw,6.8rem)] font-semibold leading-[0.92] tracking-[-0.065em] text-[#171717] dark:text-white">
            Read the board.
            <br />
            Make the move.
          </h1>
          <p className="mt-7 max-w-lg text-pretty text-sm leading-6 text-black/45 dark:text-white/45 sm:text-base sm:leading-7">
            A quiet control surface for live TFT analysis. Start the service to capture the board
            and inspect the current session.
          </p>
          <button
            type="button"
            disabled={pending}
            onClick={toggleService}
            className={clsx(
              "group mt-9 inline-flex h-10 items-center gap-2 rounded-md px-4 text-[13px] font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/60 disabled:cursor-wait disabled:opacity-50 dark:focus-visible:ring-white/60",
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

        <div className="mt-20 grid max-w-2xl grid-cols-2 border-y border-black/10 dark:border-white/10 sm:grid-cols-3">
          <Metric label="Service" value={isRunning ? "Running" : "Idle"} />
          <Metric label="Transport" value="SSE" />
          <Metric
            className="col-span-2 border-t border-black/10 dark:border-white/10 sm:col-span-1 sm:border-t-0"
            label="Client"
            value={clientId.slice(0, 8)}
            mono
          />
        </div>
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
    </main>
  );
}

function Metric({
  label,
  value,
  mono,
  className,
}: {
  label: string;
  value: string;
  mono?: boolean;
  className?: string;
}) {
  return (
    <div
      className={clsx(
        "py-5 pr-8 sm:border-r sm:border-black/10 sm:px-6 sm:first:pl-0 sm:last:border-r-0 dark:sm:border-white/10",
        className,
      )}
    >
      <div className="text-[10px] uppercase tracking-[0.16em] text-black/40 dark:text-white/30">
        {label}
      </div>
      <div
        className={clsx(
          "mt-2 text-sm text-black/70 dark:text-white/75",
          mono && "font-mono text-xs",
        )}
      >
        {value}
      </div>
    </div>
  );
}
