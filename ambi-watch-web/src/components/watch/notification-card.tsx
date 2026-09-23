import type { ReactNode } from "react";
import { cx } from "@/lib/cx";

export interface NotificationCardProps {
  title: string;
  subtitle?: string;
  icon?: ReactNode;
  className?: string;
}

/** Light 378×148 card, 40px radius, sitting above a stack (02 right). */
export function NotificationCard({ title, subtitle, icon, className }: NotificationCardProps) {
  return (
    <div
      className={cx(
        "flex h-[148px] w-[378px] items-start justify-between rounded-watch-card bg-watch-card-light pl-[32px] pr-[32px] pt-[29px]",
        className,
      )}
    >
      <div className="flex min-w-0 flex-col">
        <p className="truncate text-watch-title text-watch-card-light-label">{title}</p>
        {subtitle && <p className="truncate text-watch-body text-watch-card-light-secondary">{subtitle}</p>}
      </div>
      {icon && <div className="shrink-0 self-center">{icon}</div>}
    </div>
  );
}
