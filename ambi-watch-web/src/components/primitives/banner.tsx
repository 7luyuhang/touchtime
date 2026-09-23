import type { ComponentPropsWithoutRef } from "react";
import { cx } from "@/lib/cx";

/** DESIGN.md `banner-marketing`: the "Introducing X" announcement pill. */
export function Banner({ className, ...props }: ComponentPropsWithoutRef<"div">) {
  return (
    <div
      className={cx(
        "inline-flex items-center gap-xs rounded-full bg-canvas-soft px-sm py-xs text-body-sm text-body elevation-1",
        className,
      )}
      {...props}
    />
  );
}
