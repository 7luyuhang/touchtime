import type { ReactNode } from "react";
import { cx } from "@/lib/cx";

export interface ListCardProps {
  title: string;
  subtitle?: string;
  icon?: ReactNode;
  /** `inline`: pill with trailing icon (02 left). `stacked`: icon straddles the top edge (02 middle). */
  layout?: "inline" | "stacked";
  onClick?: () => void;
  className?: string;
}

export function ListCard({ title, subtitle, icon, layout = "inline", onClick, className }: ListCardProps) {
  if (layout === "stacked") {
    return (
      <button type="button" onClick={onClick} className={cx("relative block w-full pt-[28px] text-left watch-press", className)}>
        <span className="relative block h-[138px] rounded-[48px] watch-glass-thin watch-stroke">
          <span className="absolute left-[32px] top-[30px] block text-watch-title">{title}</span>
          {subtitle && (
            <span className="absolute left-[32px] top-[71px] block text-watch-body text-watch-label-secondary">
              {subtitle}
            </span>
          )}
        </span>
        {icon && <span className="absolute left-[32px] top-0">{icon}</span>}
      </button>
    );
  }

  return (
    <button
      type="button"
      onClick={onClick}
      className={cx(
        "relative flex h-watch-list-card w-full shrink-0 justify-between gap-md rounded-full pl-[32px] pr-[32px] text-left watch-glass-thin watch-stroke watch-press",
        subtitle ? "items-start pt-[27px]" : "items-center",
        className,
      )}
    >
      <span className="flex min-w-0 flex-col">
        <span className="truncate text-watch-title">{title}</span>
        {subtitle && <span className="truncate text-watch-body text-watch-label-secondary">{subtitle}</span>}
      </span>
      {icon && <span className={cx("shrink-0", subtitle && "mt-[16px]")}>{icon}</span>}
    </button>
  );
}
