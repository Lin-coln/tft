import { useEffect, useState } from "react";
import clsx from "clsx";
import { HiOutlineCamera, HiOutlinePhoto } from "react-icons/hi2";

import { screenshot } from "@stores/tft";

export function Screenshot() {
  const [pending, setPending] = useState(false);
  const [url, setUrl] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    return () => {
      if (url) URL.revokeObjectURL(url);
    };
  }, [url]);

  async function capture() {
    setPending(true);
    setError(null);

    try {
      const data = await screenshot();
      setUrl(
        URL.createObjectURL(new Blob([data.slice().buffer as ArrayBuffer], { type: "image/png" })),
      );
    } catch (error) {
      setError(error instanceof Error ? error.message : String(error));
    } finally {
      setPending(false);
    }
  }

  return (
    <div className="mt-6">
      <div className="mb-2.5 flex items-center justify-between gap-3">
        <div className="flex items-center gap-3 font-mono text-[10px] uppercase tracking-[0.14em] text-black/35 dark:text-white/30">
          <span>Board capture</span>
          <span>{url ? "Latest frame" : "No screenshot"}</span>
        </div>
        <button
          type="button"
          disabled={pending}
          onClick={capture}
          className="inline-flex h-8 items-center gap-2 rounded-md border border-black/10 bg-white/70 px-3 text-[11px] font-medium text-black/65 transition hover:border-black/20 hover:bg-white hover:text-black focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/60 disabled:cursor-wait disabled:opacity-50 dark:border-white/10 dark:bg-white/[0.04] dark:text-white/65 dark:hover:border-white/20 dark:hover:bg-white/[0.08] dark:hover:text-white dark:focus-visible:ring-white/60"
        >
          <HiOutlineCamera className={clsx("size-3.5", pending && "animate-pulse")} />
          {pending ? "Capturing…" : "Screenshot"}
        </button>
      </div>

      <div className="relative grid aspect-video place-items-center overflow-hidden rounded-xl border border-black/10 bg-[#eeeeec] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.55)] dark:border-white/10 dark:bg-[#0a0a0a] dark:shadow-[inset_0_0_0_1px_rgba(255,255,255,0.025)]">
        <span className="pointer-events-none absolute left-3 top-3 size-5 border-l border-t border-black/20 dark:border-white/20" />
        <span className="pointer-events-none absolute bottom-3 right-3 size-5 border-b border-r border-black/20 dark:border-white/20" />
        {url ? (
          <img
            src={url}
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

      {error && (
        <p role="alert" className="mt-2 text-xs text-red-600 dark:text-red-400">
          Screenshot failed: {error}
        </p>
      )}
    </div>
  );
}
