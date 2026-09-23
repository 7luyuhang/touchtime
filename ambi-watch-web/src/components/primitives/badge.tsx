import type { ComponentPropsWithoutRef } from "react";
import { cx } from "@/lib/cx";

export type BadgeVariant = "secondary" | "inverted" | "info" | "warning" | "error" | "violet" | "cyan";

const variants: Record<BadgeVariant, string> = {
  secondary: "bg-canvas-soft-2 text-body",
  inverted: "bg-primary text-on-primary",
  info: "bg-link-bg-soft text-link-deep",
  warning: "bg-warning-soft text-warning-deep",
  error: "bg-error-soft text-error-deep",
  violet: "bg-violet-soft text-violet-deep",
  cyan: "bg-cyan-soft text-cyan-deep",
};

export interface BadgeProps extends ComponentPropsWithoutRef<"span"> {
  variant?: BadgeVariant;
  mono?: boolean;
}

/** DESIGN.md `badge-secondary` plus soft semantic fills from the palette. */
export function Badge({ variant = "secondary", mono = false, className, ...props }: BadgeProps) {
  return (
    <span
      className={cx(
        "inline-flex h-5 items-center gap-xxs whitespace-nowrap rounded-full px-xs",
        mono ? "font-mono text-caption-mono" : "text-caption",
        variants[variant],
        className,
      )}
      {...props}
    />
  );
}
