import type { ComponentPropsWithoutRef, ReactNode } from "react";
import { cx } from "@/lib/cx";

export type RoundButtonSize = "sm" | "lg";
export type RoundButtonTone = "glass" | "mint" | "red";

const sizes: Record<RoundButtonSize, string> = {
  sm: "size-watch-button-sm",
  lg: "size-watch-button-lg",
};

const tones: Record<RoundButtonTone, string> = {
  glass: "watch-glass watch-stroke",
  mint: "watch-glass watch-stroke watch-stroke-mint",
  red: "watch-glass watch-stroke watch-stroke-red",
};

export interface RoundButtonProps extends Omit<ComponentPropsWithoutRef<"button">, "aria-label" | "children"> {
  label: string;
  icon: ReactNode;
  size?: RoundButtonSize;
  tone?: RoundButtonTone;
}

/** Circular glass button: 80px (close, back) or 102px (camera). */
export function RoundButton({ label, icon, size = "sm", tone = "glass", className, type = "button", ...props }: RoundButtonProps) {
  return (
    <button
      type={type}
      aria-label={label}
      className={cx(
        "relative flex shrink-0 items-center justify-center rounded-full text-watch-white watch-press",
        sizes[size],
        tones[tone],
        className,
      )}
      {...props}
    >
      {icon}
    </button>
  );
}
