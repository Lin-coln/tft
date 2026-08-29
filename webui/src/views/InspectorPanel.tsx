import { cx } from "class-variance-authority";
import { HiOutlineCommandLine } from "react-icons/hi2";
import { setActivePanel } from "@stores/app";
import { useClientId } from "@stores/event";
import { useTFTStore } from "@stores/tft";
import { SidePanel } from "@components/SidePanel";

export function InspectorPanel() {
  const clientId = useClientId();
  const state = useTFTStore();

  return (
    <SidePanel
      title="Inspector"
      icon={<HiOutlineCommandLine className="size-4 text-black/40 dark:text-white/40" />}
      onClose={() => setActivePanel(null)}
    >
      <div className="space-y-5 p-4">
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
    </SidePanel>
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
        className={cx(
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
