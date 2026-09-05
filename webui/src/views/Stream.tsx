import { useEffect, useRef, useState } from "react";
import { cx } from "class-variance-authority";
import { HiOutlineSignal } from "react-icons/hi2";

import { config } from "@shared/liveStream.ts";
import { Stream as LiveStream, type StreamStatus } from "@stores/live";

export function Stream() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [status, setStatus] = useState<StreamStatus>("connecting");
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let active = true;
    let stream: LiveStream | null = null;

    try {
      stream = new LiveStream({
        onFrame(frame) {
          try {
            const context = canvasRef.current?.getContext("2d");
            context?.drawImage(frame, 0, 0, config.width, config.height);
          } finally {
            frame.close();
          }
        },
        onError(streamError) {
          if (!active) return;
          setError(streamError instanceof Error ? streamError.message : String(streamError));
        },
        onStatus(nextStatus) {
          if (active) setStatus(nextStatus);
        },
      });
      stream.connect();
    } catch (streamError) {
      setError(streamError instanceof Error ? streamError.message : String(streamError));
      setStatus("disconnected");
    }

    return () => {
      active = false;
      stream?.close();
    };
  }, []);

  return (
    <div className="mt-6">
      <div className="mb-2.5 flex items-center justify-between gap-3">
        <div className="flex items-center gap-3 font-mono text-[10px] uppercase tracking-[0.14em] text-black/35 dark:text-white/30">
          <span>Live stream</span>
          <span>{status}</span>
        </div>
        <HiOutlineSignal
          className={cx(
            "size-4",
            status === "connected"
              ? "text-emerald-500"
              : status === "connecting"
                ? "animate-pulse text-amber-500"
                : "text-black/25 dark:text-white/25",
          )}
        />
      </div>

      <div className="relative grid aspect-video place-items-center overflow-hidden rounded-xl border border-black/10 bg-[#eeeeec] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.55)] dark:border-white/10 dark:bg-[#0a0a0a] dark:shadow-[inset_0_0_0_1px_rgba(255,255,255,0.025)]">
        <span className="pointer-events-none absolute left-3 top-3 z-10 size-5 border-l border-t border-white/30 mix-blend-difference" />
        <span className="pointer-events-none absolute bottom-3 right-3 z-10 size-5 border-b border-r border-white/30 mix-blend-difference" />
        <canvas
          ref={canvasRef}
          width={config.width}
          height={config.height}
          aria-label="Decoded live video stream"
          className="block size-full object-contain"
        />
      </div>

      {error && (
        <p role="alert" className="mt-2 text-xs text-red-600 dark:text-red-400">
          Live stream failed: {error}
        </p>
      )}
    </div>
  );
}
