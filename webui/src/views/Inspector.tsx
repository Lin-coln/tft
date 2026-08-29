import clsx from "clsx";
import { HiOutlineCommandLine, HiXMark } from "react-icons/hi2";

interface InspectorProps {
  id: string;
  onClose: () => void;
  clientId: string;
  state: unknown;
}

export function Inspector({ id, onClose, clientId, state }: InspectorProps) {
  return (
    <aside
      id={id}
      className="fixed inset-y-0 right-0 z-50 flex h-dvh w-full max-w-[560px] flex-col border-l border-black/15 bg-white/98 shadow-[-8px_0_24px_rgba(0,0,0,0.12)] backdrop-blur-xl dark:border-white/15 dark:bg-[#0a0a0a]/98 dark:shadow-[-8px_0_24px_rgba(0,0,0,0.28)]"
    >
      <div className="flex items-center justify-between border-b border-black/10 px-4 py-3 dark:border-white/10">
        <div className="flex items-center gap-2 text-xs font-medium">
          <HiOutlineCommandLine className="size-4 text-black/40 dark:text-white/40" /> Inspector
        </div>
        <button
          type="button"
          aria-label="Close inspector"
          onClick={onClose}
          className="grid size-7 place-items-center rounded-md text-black/40 transition hover:bg-black/[0.06] hover:text-black focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/50 dark:text-white/35 dark:hover:bg-white/[0.06] dark:hover:text-white dark:focus-visible:ring-white/50"
        >
          <HiXMark className="size-4" />
        </button>
      </div>

      <div className="min-h-0 flex-1 space-y-5 overflow-y-auto p-4">
        <InspectorRow label="Connection" value="Connected" status />
        <InspectorRow label="Client ID" value={clientId} mono />
        <div>
          <div className="mb-2 text-[10px] uppercase tracking-[0.15em] text-black/40 dark:text-white/30">
            Current snapshot
          </div>
          <pre className="min-h-64 overflow-auto rounded-lg border border-black/10 bg-[#f5f5f5] p-3 font-mono text-[11px] leading-5 text-black/65 selection:bg-[#171717] selection:text-white dark:border-white/10 dark:bg-black dark:text-white/55 dark:selection:bg-white dark:selection:text-black">
            {JSON.stringify(state, null, 2)}
          </pre>
        </div>
      </div>

      <div className="border-t border-black/10 px-4 py-3 font-mono text-[10px] text-black/30 dark:border-white/10 dark:text-white/25">
        updated from /api/services/tft
      </div>
    </aside>
  );
}

function InspectorRow({
  label,
  value,
  mono,
  status,
}: {
  label: string;
  value: string;
  mono?: boolean;
  status?: boolean;
}) {
  return (
    <div className="flex items-start justify-between gap-5">
      <span className="text-xs text-black/40 dark:text-white/35">{label}</span>
      <span
        className={clsx(
          "min-w-0 truncate text-right text-xs text-black/70 dark:text-white/70",
          mono && "font-mono text-[10px]",
        )}
      >
        {status && (
          <span className="mr-2 inline-block size-1.5 rounded-full bg-[#52a8ff] shadow-[0_0_6px_#52a8ff]" />
        )}
        {value}
      </span>
    </div>
  );
}
