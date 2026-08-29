import { useEffect, useId, useState } from "react";
import clsx from "clsx";
import {
  HiOutlineArrowUpRight,
  HiOutlineBolt,
  HiOutlineChartBar,
  HiOutlineHome,
  HiOutlinePlay,
  HiOutlineQueueList,
  HiOutlineSquare2Stack,
  HiOutlineStop,
} from "react-icons/hi2";

import { connect, useClientId } from "../stores/event";
import { start, stop, useTFTStore } from "../stores/tft";
import { Inspector } from "./Inspector";

const navigation = [
  { label: "Overview", icon: HiOutlineHome, active: true },
  { label: "Timeline", icon: HiOutlineChartBar },
  { label: "Snapshots", icon: HiOutlineSquare2Stack },
];

export function App() {
  useEffect(() => connect(), []);
  const clientId = useClientId();
  const tft = useTFTStore();
  const [inspectorOpen, setInspectorOpen] = useState(false);
  const [pending, setPending] = useState(false);
  const inspectorId = useId();
  const isRunning = tft.status === "running";

  async function toggleService() {
    setPending(true);
    try {
      await (isRunning ? stop() : start());
    } finally {
      setPending(false);
    }
  }

  return (
    <main className="relative min-h-dvh overflow-hidden bg-[#050505] text-[#ededed]">
      <div className="pointer-events-none absolute inset-0 bg-[linear-gradient(rgba(255,255,255,0.025)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.025)_1px,transparent_1px)] bg-[size:48px_48px] [mask-image:linear-gradient(to_bottom,black,transparent_72%)]" />
      <header className="relative z-10 flex h-16 items-center justify-between border-b border-white/[0.08] px-5 sm:px-8">
        <div className="flex items-center gap-3">
          <div className="grid size-7 place-items-center rounded-md border border-white/15 bg-white text-[11px] font-black tracking-[-0.08em] text-black">
            TF
          </div>
          <div className="h-4 w-px bg-white/10" />
          <span className="text-[13px] font-medium text-white/65">Match workspace</span>
        </div>
        <div className="flex items-center gap-2 font-mono text-[10px] uppercase tracking-[0.14em] text-white/35">
          <span
            className={clsx(
              "size-1.5 rounded-full",
              isRunning ? "bg-[#52a8ff] shadow-[0_0_8px_#52a8ff]" : "bg-white/25",
            )}
          />
          {isRunning ? "Live" : "Standby"}
        </div>
      </header>

      <section className="relative z-10 mx-auto flex min-h-[calc(100dvh-4rem)] max-w-6xl flex-col justify-between px-5 pb-32 pt-16 sm:px-8 sm:pt-24">
        <div>
          <div className="mb-8 flex items-center gap-2 text-[11px] font-medium uppercase tracking-[0.18em] text-white/35">
            <HiOutlineBolt className="size-3.5" /> Session control
          </div>
          <h1 className="max-w-3xl text-balance text-[clamp(2.8rem,7vw,6.8rem)] font-semibold leading-[0.92] tracking-[-0.065em] text-white">
            Read the board.
            <br />
            Make the move.
          </h1>
          <p className="mt-7 max-w-lg text-pretty text-sm leading-6 text-white/45 sm:text-base sm:leading-7">
            A quiet control surface for live TFT analysis. Start the service to capture the board
            and inspect the current session.
          </p>
          <button
            type="button"
            disabled={pending}
            onClick={toggleService}
            className={clsx(
              "group mt-9 inline-flex h-10 items-center gap-2 rounded-md px-4 text-[13px] font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/60 disabled:cursor-wait disabled:opacity-50",
              isRunning
                ? "border border-white/12 bg-white/[0.04] text-white hover:bg-white/[0.08]"
                : "bg-white text-black hover:bg-white/85",
            )}
          >
            {isRunning ? <HiOutlineStop className="size-4" /> : <HiOutlinePlay className="size-4" />}
            {pending ? "Updating…" : isRunning ? "Stop session" : "Start session"}
            {!isRunning && (
              <HiOutlineArrowUpRight className="ml-1 size-3.5 transition-transform group-hover:-translate-y-0.5 group-hover:translate-x-0.5" />
            )}
          </button>
        </div>

        <div className="mt-20 grid max-w-2xl grid-cols-2 border-y border-white/[0.08] sm:grid-cols-3">
          <Metric label="Service" value={isRunning ? "Running" : "Idle"} />
          <Metric label="Transport" value="SSE" />
          <Metric
            className="col-span-2 border-t border-white/[0.08] sm:col-span-1 sm:border-t-0"
            label="Client"
            value={clientId.slice(0, 8)}
            mono
          />
        </div>
      </section>

      <div className="fixed inset-x-0 bottom-5 z-40 flex justify-center px-4 sm:bottom-7">
        <nav
          aria-label="Primary navigation"
          className="flex h-12 items-center gap-1 rounded-xl border border-white/[0.12] bg-[#0a0a0a]/95 p-1 shadow-[0_16px_48px_rgba(0,0,0,0.65)] backdrop-blur-xl"
        >
          {navigation.map(({ label, icon: Icon, active }) => (
            <button
              key={label}
              type="button"
              aria-label={label}
              className={clsx(
                "grid size-9 place-items-center rounded-lg transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/50",
                active
                  ? "bg-white/[0.1] text-white"
                  : "text-white/35 hover:bg-white/[0.06] hover:text-white/75",
              )}
            >
              <Icon className="size-[17px]" />
            </button>
          ))}
          <div className="mx-1 h-5 w-px bg-white/10" />
          <button
            type="button"
            aria-label="Toggle inspector"
            aria-expanded={inspectorOpen}
            aria-controls={inspectorId}
            onClick={() => setInspectorOpen((value) => !value)}
            className={clsx(
              "flex h-9 items-center gap-2 rounded-lg px-3 text-xs font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/50",
              inspectorOpen
                ? "bg-white text-black"
                : "text-white/60 hover:bg-white/[0.06] hover:text-white",
            )}
          >
            <HiOutlineQueueList className="size-[17px]" />
            <span>Inspector</span>
          </button>
        </nav>
      </div>

      <Inspector
        id={inspectorId}
        open={inspectorOpen}
        onClose={() => setInspectorOpen(false)}
        clientId={clientId}
        state={tft}
      />
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
        "py-5 pr-8 sm:border-r sm:border-white/[0.08] sm:px-6 sm:first:pl-0 sm:last:border-r-0",
        className,
      )}
    >
      <div className="text-[10px] uppercase tracking-[0.16em] text-white/30">{label}</div>
      <div className={clsx("mt-2 text-sm text-white/75", mono && "font-mono text-xs")}>
        {value}
      </div>
    </div>
  );
}
