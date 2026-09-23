import type { ColorName } from "./vercel";

/**
 * The DESIGN.md only specifies a light surface (plus the polarity-flipped
 * `primary` band). These dark values are provisional Geist-style neutrals so
 * controls can be reviewed on a dark surface; replace them with the Figma
 * watch palette once it is pulled.
 */
export const darkColorOverrides = {
  primary: "#ededed",
  "on-primary": "#0a0a0a",
  ink: "#ededed",
  body: "#a1a1a1",
  mute: "#878787",
  hairline: "#2e2e2e",
  "hairline-strong": "#454545",
  canvas: "#0a0a0a",
  "canvas-soft": "#000000",
  "canvas-soft-2": "#1a1a1a",
  "selection-bg": "#ededed",
  "selection-fg": "#0a0a0a",
} as const satisfies Partial<Record<ColorName, string>>;

export const darkHairlineRing = "inset 0 0 0 1px #ffffff1f";

export const themes = ["light", "dark"] as const;
export type ThemeName = (typeof themes)[number];
