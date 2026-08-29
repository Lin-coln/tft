import type { ComponentPropsWithoutRef } from "react";
import { cva, cx, type VariantProps } from "class-variance-authority";

const buttonVariants = cva(
  cx(
    "inline-flex items-center justify-center",
    "font-medium transition",
    "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-black/50 dark:focus-visible:ring-white/50",
    "disabled:opacity-50",
  ),
  {
    variants: {
      variant: {
        solid: cx(
          "bg-[#171717] text-white dark:bg-white dark:text-black",
          "hover:bg-black/80 dark:hover:bg-white/85",
        ),
        outline: cx(
          "border border-black/10 bg-black/[0.04] text-[#171717] dark:border-white/10 dark:bg-white/[0.04] dark:text-white",
          "hover:border-black/20 hover:bg-black/[0.08] dark:hover:border-white/20 dark:hover:bg-white/[0.08]",
        ),
        subtle: cx(
          "text-black/60 dark:text-white/60",
          "hover:bg-black/[0.06] hover:text-black dark:hover:bg-white/[0.06] dark:hover:text-white",
        ),
      },
      size: {
        xs: cx("h-8 gap-2", "rounded-md px-3", "text-[11px]"),
        sm: cx("h-9 gap-2", "rounded-lg px-3", "text-xs"),
        default: cx("h-10 gap-2", "rounded-md px-4", "text-[13px]"),
        "icon-sm": cx("size-7", "rounded-md"),
        icon: cx("size-9", "rounded-lg"),
      },
    },
    defaultVariants: {
      variant: "solid",
      size: "default",
    },
  },
);

export type ButtonProps = ComponentPropsWithoutRef<"button"> & VariantProps<typeof buttonVariants>;

export function Button({ type = "button", variant, size, className, ...props }: ButtonProps) {
  return <button {...props} type={type} className={buttonVariants({ variant, size, className })} />;
}
