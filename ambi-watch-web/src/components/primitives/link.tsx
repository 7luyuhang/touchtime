import NextLink from "next/link";
import type { ComponentProps } from "react";
import { cx } from "@/lib/cx";

/** DESIGN.md `link-inline`: link blue, underlined, deepens on hover. */
export function TextLink({ className, ...props }: ComponentProps<typeof NextLink>) {
  return (
    <NextLink
      className={cx(
        "text-link underline decoration-1 underline-offset-2 transition-colors hover:text-link-deep",
        className,
      )}
      {...props}
    />
  );
}
