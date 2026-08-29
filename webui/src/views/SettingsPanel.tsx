import { cx } from "class-variance-authority";
import { HiOutlineComputerDesktop, HiOutlineMoon, HiOutlineSun } from "react-icons/hi2";
import { setActivePanel } from "@stores/app";
import { setAppearance, usePreferenceStore } from "@stores/preference";
import { SidePanel } from "@components/SidePanel";

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

export function SettingsPanel() {
  const appearance = usePreferenceStore((state) => state.appearance);

  return (
    <SidePanel title="Settings" onClose={() => setActivePanel(null)}>
      <section className="p-6">
        <div className="mb-5">
          <h2 className="text-sm font-medium text-[#171717] dark:text-white/90">Appearance</h2>
          <p className="mt-1 text-xs leading-5 text-black/40 dark:text-white/35">
            Choose how the interface looks on this device.
          </p>
        </div>

        <div className="overflow-hidden rounded-lg border border-black/10 dark:border-white/10">
          {appearances.map(({ value, label, description, icon: Icon }) => {
            const selected = appearance === value;

            return (
              <button
                key={value}
                type="button"
                aria-pressed={selected}
                onClick={() => setAppearance(value)}
                className={cx(
                  "flex w-full items-center gap-3 border-b border-black/10 px-4 py-3 text-left transition last:border-b-0 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-black/50 dark:border-white/10 dark:focus-visible:ring-white/50",
                  selected
                    ? "bg-black/[0.08] dark:bg-white/[0.08]"
                    : "hover:bg-black/[0.04] dark:hover:bg-white/[0.04]",
                )}
              >
                <span
                  className={cx(
                    "grid size-8 shrink-0 place-items-center rounded-md border",
                    selected
                      ? "border-black/20 bg-black/10 text-black dark:border-white/20 dark:bg-white/10 dark:text-white"
                      : "border-black/10 text-black/40 dark:border-white/10 dark:text-white/35",
                  )}
                >
                  <Icon className="size-4" />
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block text-xs font-medium text-black/80 dark:text-white/80">
                    {label}
                  </span>
                  <span className="mt-0.5 block text-[11px] text-black/40 dark:text-white/30">
                    {description}
                  </span>
                </span>
                <span
                  className={cx(
                    "size-3.5 rounded-full border",
                    selected
                      ? "border-[4px] border-[#171717] bg-white dark:border-white dark:bg-black"
                      : "border-black/20 dark:border-white/20",
                  )}
                />
              </button>
            );
          })}
        </div>
      </section>
    </SidePanel>
  );
}
