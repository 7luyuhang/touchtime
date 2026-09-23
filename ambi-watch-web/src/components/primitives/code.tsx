import type { ComponentPropsWithoutRef } from "react";
import { cx } from "@/lib/cx";

export function Code({ className, ...props }: ComponentPropsWithoutRef<"code">) {
  return (
    <code
      className={cx("rounded-xs bg-canvas-soft-2 px-xxs font-mono text-code text-ink", className)}
      {...props}
    />
  );
}

/** DESIGN.md `code-editor-mockup`: dark primary surface with mono text. */
export function CodeBlock({ className, ...props }: ComponentPropsWithoutRef<"pre">) {
  return (
    <pre
      className={cx(
        "overflow-x-auto rounded-md bg-primary p-lg font-mono text-code text-on-primary",
        className,
      )}
      {...props}
    />
  );
}
