import clsx from "clsx";
import { HiOutlineComputerDesktop, HiOutlineMoon, HiOutlineSun, HiXMark } from "react-icons/hi2";

import { setAppearance, usePreferenceStore } from "../stores/preference";

interface SettingsProps {
  id: string;
  onClose: () => void;
}

const appearances = [
  {
    value: "auto",
    label: "Auto",
    description: "Follow the system setting",
    icon: HiOutlineComputerDesktop,
  },
  { value: "dark", label: "Dark", description: "Always use dark appearance", icon: HiOutlineMoon },
  {
    value: "light",
    label: "Light",
    description: "Always use light appearance",
    icon: HiOutlineSun,
  },
] as const;

export function Settings({ id, onClose }: SettingsProps) {
  const appearance = usePreferenceStore((state) => state.appearance);

  return (
    <aside
      id={id}
      className="fixed inset-y-0 right-0 z-50 flex h-dvh w-full max-w-[560px] flex-col border-l border-white/[0.12] bg-[#0a0a0a]/98 shadow-[-8px_0_24px_rgba(0,0,0,0.28)] backdrop-blur-xl"
    >
      <header className="flex items-center justify-between border-b border-white/[0.08] px-4 py-3">
        <span className="text-xs font-medium">Settings</span>
        <button
          type="button"
          aria-label="Close settings"
          onClick={onClose}
          className="grid size-7 place-items-center rounded-md text-white/35 transition hover:bg-white/[0.06] hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-white/50"
        >
          <HiXMark className="size-4" />
        </button>
      </header>

      <div className="min-h-0 flex-1 overflow-y-auto p-6">
        <section aria-labelledby={`${id}-appearance`}>
          <div className="mb-5">
            <h2 id={`${id}-appearance`} className="text-sm font-medium text-white/90">
              Appearance
            </h2>
            <p className="mt-1 text-xs leading-5 text-white/35">
              Choose how the interface looks on this device.
            </p>
          </div>

          <div className="overflow-hidden rounded-lg border border-white/[0.1]">
            {appearances.map(({ value, label, description, icon: Icon }) => {
              const selected = appearance === value;

              return (
                <button
                  key={value}
                  type="button"
                  aria-pressed={selected}
                  onClick={() => setAppearance(value)}
                  className={clsx(
                    "flex w-full items-center gap-3 border-b border-white/[0.08] px-4 py-3 text-left transition last:border-b-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-white/50",
                    selected ? "bg-white/[0.08]" : "hover:bg-white/[0.04]",
                  )}
                >
                  <span
                    className={clsx(
                      "grid size-8 shrink-0 place-items-center rounded-md border",
                      selected
                        ? "border-white/20 bg-white/[0.1] text-white"
                        : "border-white/[0.08] text-white/35",
                    )}
                  >
                    <Icon className="size-4" />
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block text-xs font-medium text-white/80">{label}</span>
                    <span className="mt-0.5 block text-[11px] text-white/30">{description}</span>
                  </span>
                  <span
                    className={clsx(
                      "size-3.5 rounded-full border",
                      selected ? "border-[4px] border-white bg-black" : "border-white/20",
                    )}
                  />
                </button>
              );
            })}
          </div>
        </section>
      </div>
    </aside>
  );
}
