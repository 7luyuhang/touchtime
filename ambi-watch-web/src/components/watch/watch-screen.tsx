import type { ReactNode } from "react";
import { cx } from "@/lib/cx";

export type WatchBackground = "black" | "ambient" | "capture" | "aurora" | "photo" | "power";

const backgrounds: Record<WatchBackground, string> = {
  black: "bg-watch-black",
  ambient: "watch-gradient-ambient",
  capture: "watch-gradient-capture",
  aurora: "watch-gradient-aurora",
  photo: "watch-gradient-photo",
  power: "watch-gradient-power",
};

export interface WatchScreenProps {
  background?: WatchBackground;
  children?: ReactNode;
  className?: string;
  label?: string;
}

/** The 410×502 display. Children position themselves in screen pixels. */
export function WatchScreen({ background = "black", children, className, label }: WatchScreenProps) {
  return (
    <div
      role="region"
      aria-label={label}
      className={cx(
        "relative isolate h-(--watch-screen-height) w-(--watch-screen-width) shrink-0 overflow-hidden rounded-(--watch-screen-radius) font-watch text-watch-white select-none",
        backgrounds[background],
        className,
      )}
    >
      {children}
    </div>
  );
}
