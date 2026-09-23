import type { ComponentPropsWithoutRef, HTMLAttributes } from "react";
import { cx } from "@/lib/cx";

type HeadingSize = "xl" | "lg" | "md" | "sm";
type HeadingTag = "h1" | "h2" | "h3" | "h4" | "h5" | "h6";

const headingSizes: Record<HeadingSize, string> = {
  xl: "text-display-xl",
  lg: "text-display-lg",
  md: "text-display-md",
  sm: "text-display-sm",
};

export interface HeadingProps extends ComponentPropsWithoutRef<"h2"> {
  as?: HeadingTag;
  size?: HeadingSize;
}

/** Display type: weight 600, sentence case, negative tracking (from the token). */
export function Heading({ as: Tag = "h2", size = "lg", className, ...props }: HeadingProps) {
  return <Tag className={cx(headingSizes[size], "text-balance", className)} {...props} />;
}

type TextSize = "lg" | "md" | "sm" | "caption";
type TextTone = "ink" | "body" | "mute" | "inherit";
type TextTag = "p" | "span" | "div" | "dt" | "dd" | "li";

const textSizes: Record<TextSize, { regular: string; strong: string }> = {
  lg: { regular: "text-body-lg", strong: "text-body-lg font-medium" },
  md: { regular: "text-body-md", strong: "text-body-md-strong" },
  sm: { regular: "text-body-sm", strong: "text-body-sm-strong" },
  caption: { regular: "text-caption", strong: "text-caption font-medium" },
};

const textTones: Record<TextTone, string> = {
  ink: "text-ink",
  body: "text-body",
  mute: "text-mute",
  inherit: "",
};

export interface TextProps extends HTMLAttributes<HTMLElement> {
  as?: TextTag;
  size?: TextSize;
  strong?: boolean;
  tone?: TextTone;
}

export function Text({ as: Tag = "p", size = "md", strong = false, tone = "body", className, ...props }: TextProps) {
  const sizeClass = textSizes[size][strong ? "strong" : "regular"];
  return <Tag className={cx(sizeClass, textTones[tone], className)} {...props} />;
}

export interface EyebrowProps extends ComponentPropsWithoutRef<"p"> {
  tone?: TextTone;
}

/** Mono caption for section eyebrows and technical labels (never body copy). */
export function Eyebrow({ tone = "mute", className, ...props }: EyebrowProps) {
  return <p className={cx("font-mono text-caption-mono uppercase", textTones[tone], className)} {...props} />;
}
