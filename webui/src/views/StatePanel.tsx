import { cx } from "class-variance-authority";
import { HiOutlineCircleStack, HiOutlineShoppingBag, HiOutlineSquare2Stack } from "react-icons/hi2";
import { setActivePanel } from "@stores/app";
import { useTFTStore } from "@stores/tft";
import { SidePanel } from "@components/SidePanel";

export function StatePanel() {
  const state = useTFTStore();
  const { level, currency, shop } = state;
  const experienceKnown = level.experience.current >= 0 && level.experience.required > 0;
  const experienceProgress = experienceKnown
    ? Math.min(100, (level.experience.current / level.experience.required) * 100)
    : 0;
  const shopSlots = Array.from(
    { length: Math.max(5, shop.length) },
    (_, index) => shop[index] ?? null,
  );

  return (
    <SidePanel
      title="State"
      icon={<HiOutlineSquare2Stack className="size-4 text-black/40 dark:text-white/40" />}
      onClose={() => setActivePanel(null)}
    >
      <section className="p-6">
        <div className="mb-5">
          <h2 className="text-sm font-medium text-[#171717] dark:text-white/90">Board state</h2>
          <p className="mt-1 text-xs leading-5 text-black/40 dark:text-white/35">
            The latest values captured from the current game.
          </p>
        </div>

        <div className="overflow-hidden rounded-lg border border-black/10 dark:border-white/10">
          <div className="grid grid-cols-2">
            <StateValue label="Level" value={level.current} confidence={level.confidence} />
            <StateValue
              label="Gold"
              value={currency.current}
              confidence={currency.confidence}
              icon={<HiOutlineCircleStack className="size-3.5" />}
              borderLeft
            />
          </div>

          <div className="border-t border-black/10 px-4 py-4 dark:border-white/10">
            <div className="flex items-center justify-between text-[10px] uppercase tracking-[0.14em] text-black/40 dark:text-white/30">
              <span>Experience</span>
              <span className="font-mono tracking-normal">
                {experienceKnown
                  ? `${level.experience.current} / ${level.experience.required}`
                  : "— / —"}
              </span>
            </div>
            <div className="mt-3 h-1 overflow-hidden rounded-full bg-black/10 dark:bg-white/10">
              <div
                className="h-full rounded-full bg-[#52a8ff] transition-[width] duration-300"
                style={{ width: `${experienceProgress}%` }}
              />
            </div>
            <Confidence value={level.experience.confidence} />
          </div>
        </div>

        <div className="mb-3 mt-6 flex items-center gap-1.5 text-[10px] uppercase tracking-[0.16em] text-black/40 dark:text-white/30">
          <HiOutlineShoppingBag className="size-3.5" /> Shop
        </div>
        <div className="flex flex-col gap-1.5">
          {shopSlots.map((champion, index) => (
            <div
              key={index}
              className="flex min-h-16 min-w-0 items-end rounded-md border border-black/10 bg-black/[0.025] p-2 dark:border-white/10 dark:bg-white/[0.035]"
            >
              <span
                className={cx(
                  "truncate text-[11px] font-medium",
                  champion
                    ? "text-black/75 dark:text-white/75"
                    : "text-black/25 dark:text-white/20",
                )}
              >
                {champion?.name ?? "—"}
              </span>
              {champion && <Confidence value={champion.confidence} compact />}
            </div>
          ))}
        </div>
      </section>
    </SidePanel>
  );
}

function StateValue({
  label,
  value,
  confidence,
  icon,
  borderLeft,
}: {
  label: string;
  value: number;
  confidence: number;
  icon?: React.ReactNode;
  borderLeft?: boolean;
}) {
  return (
    <div className={cx("p-4", borderLeft && "border-l border-black/10 dark:border-white/10")}>
      <div className="flex items-center gap-1.5 text-[10px] uppercase tracking-[0.16em] text-black/40 dark:text-white/30">
        {icon} {label}
      </div>
      <div className="mt-3 text-3xl font-semibold tracking-[-0.04em]">
        {value >= 0 ? value : "—"}
      </div>
      <Confidence value={confidence} />
    </div>
  );
}

function Confidence({ value, compact = false }: { value: number; compact?: boolean }) {
  return (
    <span
      className={cx(
        "font-mono text-black/25 dark:text-white/20",
        compact ? "ml-auto text-[8px]" : "mt-2 block text-[9px]",
      )}
    >
      confidence {Number.isFinite(value) ? `${Math.round(value * 100)}%` : "—"}
    </span>
  );
}
