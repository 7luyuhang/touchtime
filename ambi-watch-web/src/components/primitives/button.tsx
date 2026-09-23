import type { ComponentPropsWithoutRef, ReactNode } from "react";
import { cx } from "@/lib/cx";

export type ButtonVariant = "primary" | "secondary" | "ghost" | "danger";
export type ButtonSize = "xs" | "sm" | "md" | "lg";
/**
 * `pill` is the marketing CTA shape (100px), `rounded` the in-app/nav shape
 * (6px). DESIGN.md: pick one scale per screen, never mix them.
 */
export type ButtonShape = "pill" | "rounded";

const variants: Record<ButtonVariant, string> = {
  primary: "bg-primary text-on-primary hover:bg-primary/85",
  secondary: "bg-canvas text-ink elevation-1 hover:bg-canvas-soft-2",
  ghost: "bg-transparent text-body hover:bg-canvas-soft-2 hover:text-ink",
  danger: "bg-error-soft text-error-deep hover:bg-error-soft/70",
};

const sizes: Record<ButtonSize, string> = {
  xs: "h-control-xs px-xs text-body-sm-strong",
  sm: "h-control-sm px-xs text-button-md",
  md: "h-control-md px-sm text-button-md",
  lg: "h-control-lg px-sm text-button-lg",
};

const shapes: Record<ButtonShape, string> = {
  pill: "rounded-pill",
  rounded: "rounded-sm",
};

export interface ButtonStyleOptions {
  variant?: ButtonVariant;
  size?: ButtonSize;
  shape?: ButtonShape;
  fullWidth?: boolean;
}

/** Exposed so links and other elements can render with button chrome. */
export function buttonStyles({
  variant = "primary",
  size = "md",
  shape = "pill",
  fullWidth = false,
}: ButtonStyleOptions = {}): string {
  return cx(
    "inline-flex shrink-0 select-none items-center justify-center gap-xs whitespace-nowrap transition-colors",
    "disabled:cursor-not-allowed disabled:bg-canvas-soft-2 disabled:text-mute disabled:elevation-1",
    variants[variant],
    sizes[size],
    shapes[shape],
    fullWidth && "w-full",
  );
}

export interface ButtonProps extends ComponentPropsWithoutRef<"button">, ButtonStyleOptions {
  leading?: ReactNode;
  trailing?: ReactNode;
}

export function Button({
  variant,
  size,
  shape,
  fullWidth,
  leading,
  trailing,
  className,
  children,
  type = "button",
  ...props
}: ButtonProps) {
  return (
    <button type={type} className={cx(buttonStyles({ variant, size, shape, fullWidth }), className)} {...props}>
      {leading}
      {children}
      {trailing}
    </button>
  );
}
