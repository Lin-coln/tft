import { useEffect, useId, useState } from "react";
import clsx from "clsx";
import {
  HiOutlineArrowUpRight,
  HiOutlineBolt,
  HiOutlineCamera,
  HiOutlineChartBar,
  HiOutlineHome,
  HiOutlinePlay,
  HiOutlinePhoto,
  HiOutlineQueueList,
  HiOutlineCog6Tooth,
  HiOutlineSquare2Stack,
  HiOutlineStop,
} from "react-icons/hi2";
import { connect, useClientId } from "@stores/event";
import { screenshot, start, stop, useTFTStore } from "@stores/tft";
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
  const [capturePending, setCapturePending] = useState(false);
  const [screenshotUrl, setScreenshotUrl] = useState<string | null>(null);
  const [captureError, setCaptureError] = useState<string | null>(null);
  const inspectorId = useId();
  const settingsId = useId();
  const isRunning = tft.status === "running";

  useEffect(() => {
    document.documentElement.dataset.appearance = appearance;
    document.documentElement.style.colorScheme = appearance;
  }, [appearance]);

  useEffect(() => {
    return () => {
      if (screenshotUrl) URL.revokeObjectURL(screenshotUrl);
    };
  }, [screenshotUrl]);

  async function toggleService() {
    setPending(true);
    try {
      await (isRunning ? stop() : start());
    } finally {
      setPending(false);
    }
  }

  async function captureScreenshot() {
    setCapturePending(true);
    setCaptureError(null);

    try {
      const data = await screenshot();
      setScreenshotUrl(
        URL.createObjectURL(new Blob([data.slice().buffer as ArrayBuffer], { type: "image/png" })),
      );
    } catch (error) {
      setCaptureError(error instanceof Error ? error.message : String(error));
    } finally {
      setCapturePending(false);
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
            <button
              type="button"
              disabled={capturePending}
              onClick={captureScreenshot}
              className="inline-flex h-10 items-center gap-2 rounded-md border border-black/10 bg-white/70 px-4 text-[13px] font-medium text-black/65 transition hover:border-black/20 hover:bg-white hover:text-black focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/60 disabled:cursor-wait disabled:opacity-50 dark:border-white/10 dark:bg-white/[0.04] dark:text-white/65 dark:hover:border-white/20 dark:hover:bg-white/[0.08] dark:hover:text-white dark:focus-visible:ring-white/60"
            >
              <HiOutlineCamera className={clsx("size-4", capturePending && "animate-pulse")} />
              {capturePending ? "Capturing…" : "Screenshot"}
            </button>
          </div>
        </div>

        <div className="mt-6">
          <div className="mb-2.5 flex items-center justify-between font-mono text-[10px] uppercase tracking-[0.14em] text-black/35 dark:text-white/30">
            <span>Board capture</span>
            <span>{screenshotUrl ? "Latest frame" : "No screenshot"}</span>
          </div>
          <div className="relative grid aspect-video place-items-center overflow-hidden rounded-xl border border-black/10 bg-[#eeeeec] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.55)] dark:border-white/10 dark:bg-[#0a0a0a] dark:shadow-[inset_0_0_0_1px_rgba(255,255,255,0.025)]">
            <span className="pointer-events-none absolute left-3 top-3 size-5 border-l border-t border-black/20 dark:border-white/20" />
            <span className="pointer-events-none absolute bottom-3 right-3 size-5 border-b border-r border-black/20 dark:border-white/20" />
            {screenshotUrl ? (
              <img
                src={screenshotUrl}
                alt="Latest TFT board screenshot"
                className="h-full w-full object-contain"
              />
            ) : (
              <div className="flex flex-col items-center px-6 py-16 text-center">
                <div className="grid size-12 place-items-center rounded-full border border-black/10 bg-white/60 text-black/30 dark:border-white/10 dark:bg-white/[0.04] dark:text-white/30">
                  <HiOutlinePhoto className="size-5" />
                </div>
                <p className="mt-4 text-sm font-medium text-black/55 dark:text-white/55">
                  No screenshot yet
                </p>
                <p className="mt-1.5 max-w-xs text-xs leading-5 text-black/35 dark:text-white/30">
                  Capture a frame to preview the current board here.
                </p>
              </div>
            )}
          </div>
          {captureError && (
            <p role="alert" className="mt-2 text-xs text-red-600 dark:text-red-400">
              Screenshot failed: {captureError}
            </p>
          )}
        </div>

        <div className="mt-6 grid max-w-2xl grid-cols-2 border-y border-black/10 dark:border-white/10 sm:grid-cols-3">
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
