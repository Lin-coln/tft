import clsx from "clsx";
import {
  HiOutlineCircleStack,
  HiOutlineShoppingBag,
  HiOutlineSquare2Stack,
  HiXMark,
} from "react-icons/hi2";
import type { TFTState } from "@shared/index.ts";

interface StateProps {
  id: string;
  onClose: () => void;
  state: TFTState;
}

export function State({ id, onClose, state }: StateProps) {
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
    <aside
      id={id}
      className="fixed inset-y-0 right-0 z-50 flex h-dvh w-full max-w-[560px] flex-col border-l border-black/15 bg-white/98 shadow-[-8px_0_24px_rgba(0,0,0,0.12)] backdrop-blur-xl dark:border-white/15 dark:bg-[#0a0a0a]/98 dark:shadow-[-8px_0_24px_rgba(0,0,0,0.28)]"
    >
      <header className="flex items-center justify-between border-b border-black/10 px-4 py-3 dark:border-white/10">
        <span className="flex items-center gap-2 text-xs font-medium">
          <HiOutlineSquare2Stack className="size-4 text-black/40 dark:text-white/40" /> State
        </span>
        <button
          type="button"
          aria-label="Close state"
          onClick={onClose}
          className="grid size-7 place-items-center rounded-md text-black/40 transition hover:bg-black/[0.06] hover:text-black focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/50 dark:text-white/35 dark:hover:bg-white/[0.06] dark:hover:text-white dark:focus-visible:ring-white/50"
        >
          <HiXMark className="size-4" />
        </button>
      </header>

      <div className="min-h-0 flex-1 overflow-y-auto p-6">
        <section aria-labelledby={`${id}-board`}>
          <div className="mb-5">
            <h2
              id={`${id}-board`}
              className="text-sm font-medium text-[#171717] dark:text-white/90"
            >
              Board state
            </h2>
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
          <div className="grid grid-cols-5 gap-1.5">
            {shopSlots.map((champion, index) => (
              <div
                key={index}
                className="flex min-h-16 min-w-0 items-end rounded-md border border-black/10 bg-black/[0.025] p-2 dark:border-white/10 dark:bg-white/[0.035]"
              >
                <span
                  className={clsx(
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
      </div>

      <div className="border-t border-black/10 px-4 py-3 font-mono text-[10px] text-black/30 dark:border-white/10 dark:text-white/25">
        updated from /api/services/tft
      </div>
    </aside>
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
    <div className={clsx("p-4", borderLeft && "border-l border-black/10 dark:border-white/10")}>
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
      className={clsx(
        "font-mono text-black/25 dark:text-white/20",
        compact ? "ml-auto text-[8px]" : "mt-2 block text-[9px]",
      )}
    >
      confidence {Number.isFinite(value) ? `${Math.round(value * 100)}%` : "—"}
    </span>
  );
}
