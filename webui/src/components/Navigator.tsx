import type { ReactNode } from "react";
import { cx } from "class-variance-authority";
import { Button, type ButtonProps } from "@components/Button";

interface NavigatorProps {
  ariaLabel: string;
  children: ReactNode;
}

interface NavigatorItemProps extends Omit<ButtonProps, "children" | "size" | "variant"> {
  label: string;
  icon: ReactNode;
  active?: boolean;
  activeVariant?: "solid" | "subtle";
  iconOnly?: boolean;
}

function NavigatorRoot({ ariaLabel, children }: NavigatorProps) {
  return (
    <div className={cx("fixed inset-x-0 bottom-5 z-40 sm:bottom-7", "flex justify-center", "px-4")}>
      <nav
        aria-label={ariaLabel}
        className={cx(
          "flex h-12 items-center gap-1",
          "p-1",
          "rounded-xl border",
          "border-black/15 bg-white/95 backdrop-blur-xl dark:border-white/15 dark:bg-[#0a0a0a]/95",
          "shadow-[0_16px_48px_rgba(0,0,0,0.14)] dark:shadow-[0_16px_48px_rgba(0,0,0,0.65)]",
        )}
      >
        {children}
      </nav>
    </div>
  );
}

function NavigatorItem({
  label,
  icon,
  active = false,
  activeVariant = "solid",
  iconOnly = false,
  className,
  "aria-label": ariaLabel,
  ...props
}: NavigatorItemProps) {
  return (
    <Button
      {...props}
      aria-label={ariaLabel ?? label}
      data-active={active}
      variant={active && activeVariant === "solid" ? "solid" : "subtle"}
      size={iconOnly ? "icon" : "sm"}
      className={cx(
        "[&_svg]:size-[17px]",
        activeVariant === "subtle" &&
          "data-[active=true]:bg-black/10 data-[active=true]:text-[#171717] dark:data-[active=true]:bg-white/10 dark:data-[active=true]:text-white",
        className,
      )}
    >
      {icon}
      {!iconOnly && <span>{label}</span>}
    </Button>
  );
}

function NavigatorDivider() {
  return (
    <div
      role="separator"
      aria-orientation="vertical"
      className={cx("h-5 w-px", "mx-1", "bg-black/10 dark:bg-white/10")}
    />
  );
}

export const Navigator = Object.assign(NavigatorRoot, {
  Item: NavigatorItem,
  Divider: NavigatorDivider,
});
