import { duration, easing } from "./motion";
import type { AmbiToken } from "./types";
import { colors } from "./vercel";

/**
 * ambi watch layer, sourced from Figma file mRqDXY037g9l7zv89aZR8D
 * ("Hardware - watch"). Every token is a placeholder until the Figma
 * variables are pulled; see docs/ambi-watch-design-system.md for the full
 * taxonomy still to be filled.
 */

function placeholder(value: string, options: Omit<AmbiToken, "value" | "status"> = {}): AmbiToken {
  return { value, status: "placeholder", ...options };
}

export const ambiColors = {
  "watch-case": placeholder(colors.body, { aliasOf: "body", note: "Hardware case/bezel colour" }),
  "watch-face": placeholder(colors.primary, { aliasOf: "primary" }),
  "watch-face-fg": placeholder(colors["on-primary"], { aliasOf: "on-primary" }),
  "watch-accent": placeholder(colors.link, { aliasOf: "link" }),
} satisfies Record<string, AmbiToken>;

export const watchFace = {
  width: placeholder("200px", { note: "Figma frame width" }),
  height: placeholder("240px", { note: "Figma frame height" }),
  radius: placeholder("48px", { note: "Screen corner radius (or 50% if the display is round)" }),
  bezel: placeholder("10px", { note: "Case/bezel thickness drawn around the screen" }),
} satisfies Record<string, AmbiToken>;

export const ambiMotion = {
  duration: placeholder(duration.base, { aliasOf: "duration.base" }),
  easing: placeholder(easing.standard, { aliasOf: "easing.standard" }),
} satisfies Record<string, AmbiToken>;

export const ambiTokenGroups = {
  Color: ambiColors,
  "Watch face": watchFace,
  Motion: ambiMotion,
} as const;
