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
      className="fixed inset-y-0 right-0 z-50 flex h-dvh w-full max-w-[560px] flex-col border-l border-white/[0.12] bg-[#0a0a0a]/98 shadow-[-8px_0_24px_rgba(0,0,0,0.28)] backdrop-blur-xl"
    >
      <div className="flex items-center justify-between border-b border-white/[0.08] px-4 py-3">
        <div className="flex items-center gap-2 text-xs font-medium">
          <HiOutlineCommandLine className="size-4 text-white/40" /> Inspector
        </div>
        <button
          type="button"
          aria-label="Close inspector"
          onClick={onClose}
          className="grid size-7 place-items-center rounded-md text-white/35 transition hover:bg-white/[0.06] hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/50"
        >
          <HiXMark className="size-4" />
        </button>
      </div>

      <div className="min-h-0 flex-1 space-y-5 overflow-y-auto p-4">
        <InspectorRow label="Connection" value="Connected" status />
        <InspectorRow label="Client ID" value={clientId} mono />
        <div>
          <div className="mb-2 text-[10px] uppercase tracking-[0.15em] text-white/30">
            Current snapshot
          </div>
          <pre className="min-h-64 overflow-auto rounded-lg border border-white/[0.08] bg-black p-3 font-mono text-[11px] leading-5 text-white/55 selection:bg-white selection:text-black">
            {JSON.stringify(state, null, 2)}
          </pre>
        </div>
      </div>

      <div className="border-t border-white/[0.08] px-4 py-3 font-mono text-[10px] text-white/25">
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
      <span className="text-xs text-white/35">{label}</span>
      <span
        className={clsx(
          "min-w-0 truncate text-right text-xs text-white/70",
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
