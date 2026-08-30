import { useEffect, useState } from "react";
import { cx } from "class-variance-authority";
import { HiOutlineCamera, HiOutlinePhoto } from "react-icons/hi2";

import { Button } from "@components/Button";
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
        <Button
          disabled={pending}
          onClick={capture}
          variant="outline"
          size="xs"
          className={cx("disabled:cursor-wait")}
        >
          <HiOutlineCamera className={cx("size-3.5", pending && "animate-pulse")} />
          {pending ? "Capturing…" : "Screenshot"}
        </Button>
      </div>

      <div className="relative grid aspect-video place-items-center overflow-hidden rounded-xl border border-black/10 bg-[#eeeeec] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.55)] dark:border-white/10 dark:bg-[#0a0a0a] dark:shadow-[inset_0_0_0_1px_rgba(255,255,255,0.025)]">
        <span className="pointer-events-none absolute left-3 top-3 size-5 border-l border-t border-black/20 dark:border-white/20" />
        <span className="pointer-events-none absolute bottom-3 right-3 size-5 border-b border-r border-black/20 dark:border-white/20" />
        {url ? (
          <img
            src={url}
            alt="Latest TFT board screenshot"
            className="absolute inset-0 block size-full object-contain"
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
