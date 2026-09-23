import type { ReactNode } from "react";
import { cx } from "@/lib/cx";
import { RoundButton } from "./round-button";
import { CloseGlyph } from "./watch-icons";

export const DEFAULT_TIME = "10:09";

/** 92px (46pt) top area with the time centred (06). */
export function StatusBar({ time = DEFAULT_TIME, className }: { time?: string; className?: string }) {
  return (
    <div className={cx("pointer-events-none absolute inset-x-0 top-0 z-20 h-(--watch-screen-status-bar)", className)}>
      <p className="absolute inset-x-0 top-[27px] text-center text-watch-time">{time}</p>
    </div>
  );
}

export function CloseButton({ onClick, className }: { onClick?: () => void; className?: string }) {
  return (
    <div className={cx("absolute z-20", className)}>
      <RoundButton label="Close" icon={<CloseGlyph />} onClick={onClick} />
    </div>
  );
}

export interface ScreenHeaderProps {
  title: ReactNode;
  time?: string;
  onClose?: () => void;
}

/** Close button left, time and serif title right-aligned (02 quick actions). */
export function ScreenHeader({ title, time = DEFAULT_TIME, onClose }: ScreenHeaderProps) {
  return (
    <>
      <CloseButton onClick={onClose} className="left-[32px] top-[27px]" />
      <div className="pointer-events-none absolute inset-x-0 top-0 z-20">
        <p className="absolute right-[32px] top-[31px] text-right text-watch-time">{time}</p>
        <p className="absolute right-[34px] top-[66px] whitespace-nowrap text-right font-watch-serif text-watch-header text-watch-mint">
          {title}
        </p>
      </div>
    </>
  );
}
