import type { ComponentPropsWithoutRef } from "react";
import { cx } from "@/lib/cx";

export type CardVariant = "marketing" | "large" | "soft" | "template" | "featured";

const variants: Record<CardVariant, string> = {
  marketing: "bg-canvas text-ink rounded-md p-lg elevation-3",
  large: "bg-canvas text-ink rounded-lg p-xl elevation-4",
  soft: "bg-canvas-soft text-ink rounded-md p-lg elevation-1",
  template: "bg-canvas text-ink rounded-md p-md elevation-2",
  featured: "bg-primary text-on-primary rounded-lg p-xl",
};

export interface CardProps extends ComponentPropsWithoutRef<"div"> {
  variant?: CardVariant;
}

/** DESIGN.md card family; `featured` is the polarity-flipped surface. */
export function Card({ variant = "marketing", className, ...props }: CardProps) {
  return <div className={cx(variants[variant], className)} {...props} />;
}
