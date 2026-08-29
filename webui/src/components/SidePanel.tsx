import type { ReactNode } from "react";
import { cx } from "class-variance-authority";
import { HiXMark } from "react-icons/hi2";
import { Button } from "@components/Button";

interface SidePanelProps {
  title: string;
  icon?: ReactNode;
  onClose: () => void;
  children: ReactNode;
}

export function SidePanel({ title, icon, onClose, children }: SidePanelProps) {
  return (
    <aside
      aria-label={title}
      className={cx(
        "fixed inset-y-0 right-0 z-50",
        "h-dvh w-full max-w-140",
        "overflow-y-auto",
        "border-l",
        "border-black/15 bg-white/98 backdrop-blur-xl dark:border-white/15 dark:bg-[#0a0a0a]/98",
        "shadow-[-8px_0_24px_rgba(0,0,0,0.12)] dark:shadow-[-8px_0_24px_rgba(0,0,0,0.28)]",
      )}
    >
      <header
        className={cx(
          "sticky top-0 z-10",
          "flex items-center justify-between",
          "px-4 py-3",
          "border-b",
          "border-black/10 bg-white/95 backdrop-blur-xl dark:border-white/10 dark:bg-[#0a0a0a]/95",
        )}
      >
        <span className={cx("flex items-center gap-2", "text-xs font-medium")}>
          {icon}
          {title}
        </span>
        <Button
          aria-label={`Close ${title.toLowerCase()}`}
          onClick={onClose}
          variant="subtle"
          size="icon-sm"
        >
          <HiXMark className={cx("size-4")} />
        </Button>
      </header>

      {children}
    </aside>
  );
}
