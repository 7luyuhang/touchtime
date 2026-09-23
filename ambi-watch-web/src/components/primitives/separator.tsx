import type { ComponentPropsWithoutRef } from "react";
import { cx } from "@/lib/cx";

export function Separator({ className, ...props }: ComponentPropsWithoutRef<"hr">) {
  return <hr className={cx("border-0 border-t border-hairline", className)} {...props} />;
}
