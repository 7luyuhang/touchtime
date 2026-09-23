import type { ComponentPropsWithoutRef, ReactNode } from "react";
import { cx } from "@/lib/cx";

export type IconButtonVariant = "secondary" | "primary" | "ghost";
export type IconButtonSize = "xs" | "sm" | "md" | "lg";

const variants: Record<IconButtonVariant, string> = {
  secondary: "bg-canvas text-ink border border-hairline hover:bg-canvas-soft-2",
  primary: "bg-primary text-on-primary hover:bg-primary/85",
  ghost: "bg-transparent text-body hover:bg-canvas-soft-2 hover:text-ink",
};

const sizes: Record<IconButtonSize, string> = {
  xs: "size-control-xs",
  sm: "size-control-sm",
  md: "size-control-md",
  lg: "size-control-lg",
};

export interface IconButtonProps extends Omit<ComponentPropsWithoutRef<"button">, "aria-label" | "children"> {
  label: string;
  icon: ReactNode;
  variant?: IconButtonVariant;
  size?: IconButtonSize;
}

/** DESIGN.md `icon-button-circular`: full radius, hairline border, ink glyph. */
export function IconButton({
  label,
  icon,
  variant = "secondary",
  size = "sm",
  className,
  type = "button",
  ...props
}: IconButtonProps) {
  return (
    <button
      type={type}
      aria-label={label}
      title={label}
      className={cx(
        "inline-flex shrink-0 items-center justify-center rounded-full transition-colors",
        "disabled:cursor-not-allowed disabled:opacity-50",
        variants[variant],
        sizes[size],
        className,
      )}
      {...props}
    >
      {icon}
    </button>
  );
}
