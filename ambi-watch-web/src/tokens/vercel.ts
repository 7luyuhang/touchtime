import type { TypeStyle } from "./types";

/**
 * Foundations transcribed from the Vercel DESIGN.md
 * (VoltAgent/awesome-design-md, design-md/vercel/DESIGN.md).
 * Keep names identical to the DESIGN.md keys so specs can be cross-referenced.
 */

export const colors = {
  primary: "#171717",
  "on-primary": "#ffffff",
  ink: "#171717",
  body: "#4d4d4d",
  mute: "#888888",
  hairline: "#ebebeb",
  "hairline-strong": "#a1a1a1",
  canvas: "#ffffff",
  "canvas-soft": "#fafafa",
  "canvas-soft-2": "#f5f5f5",
  link: "#0070f3",
  "link-deep": "#0761d1",
  "link-bg-soft": "#d3e5ff",
  success: "#0070f3",
  error: "#ee0000",
  "error-soft": "#f7d4d6",
  "error-deep": "#c50000",
  warning: "#f5a623",
  "warning-soft": "#ffefcf",
  "warning-deep": "#ab570a",
  violet: "#7928ca",
  "violet-soft": "#d8ccf1",
  "violet-deep": "#4c2889",
  cyan: "#50e3c2",
  "cyan-soft": "#aaffec",
  "cyan-deep": "#29bc9b",
  "highlight-pink": "#ff0080",
  "highlight-magenta": "#eb367f",
  "gradient-develop-start": "#007cf0",
  "gradient-develop-end": "#00dfd8",
  "gradient-preview-start": "#7928ca",
  "gradient-preview-end": "#ff0080",
  "gradient-ship-start": "#ff4d4d",
  "gradient-ship-end": "#f9cb28",
  "selection-bg": "#171717",
  "selection-fg": "#f2f2f2",
} as const;

export type ColorName = keyof typeof colors;

export const colorGroups: Record<string, ColorName[]> = {
  Surface: ["canvas", "canvas-soft", "canvas-soft-2", "primary", "on-primary"],
  Text: ["ink", "body", "mute"],
  Border: ["hairline", "hairline-strong"],
  Semantic: [
    "link",
    "link-deep",
    "link-bg-soft",
    "success",
    "error",
    "error-soft",
    "error-deep",
    "warning",
    "warning-soft",
    "warning-deep",
  ],
  Accent: [
    "violet",
    "violet-soft",
    "violet-deep",
    "cyan",
    "cyan-soft",
    "cyan-deep",
    "highlight-pink",
    "highlight-magenta",
  ],
  Gradient: [
    "gradient-develop-start",
    "gradient-develop-end",
    "gradient-preview-start",
    "gradient-preview-end",
    "gradient-ship-start",
    "gradient-ship-end",
  ],
  Selection: ["selection-bg", "selection-fg"],
};

export const fontStacks = {
  sans: "var(--font-geist-sans), Inter, system-ui, -apple-system, sans-serif",
  mono: "var(--font-geist-mono), ui-monospace, SFMono-Regular, Menlo, Monaco, monospace",
} as const;

/** DESIGN.md: the sans never appears at 700+; 600 is the display ceiling. */
export const fontWeights = {
  regular: 400,
  medium: 500,
  semibold: 600,
} as const;

export const typography = {
  "display-xl": { fontFamily: "sans", fontSize: 48, fontWeight: 600, lineHeight: 48, letterSpacing: -2.4 },
  "display-lg": { fontFamily: "sans", fontSize: 32, fontWeight: 600, lineHeight: 40, letterSpacing: -1.28 },
  "display-md": { fontFamily: "sans", fontSize: 24, fontWeight: 600, lineHeight: 32, letterSpacing: -0.96 },
  "display-sm": { fontFamily: "sans", fontSize: 20, fontWeight: 600, lineHeight: 28, letterSpacing: -0.6 },
  "body-lg": { fontFamily: "sans", fontSize: 18, fontWeight: 400, lineHeight: 28, letterSpacing: 0 },
  "body-md": { fontFamily: "sans", fontSize: 16, fontWeight: 400, lineHeight: 24, letterSpacing: 0 },
  "body-md-strong": { fontFamily: "sans", fontSize: 16, fontWeight: 500, lineHeight: 24, letterSpacing: 0 },
  "body-sm": { fontFamily: "sans", fontSize: 14, fontWeight: 400, lineHeight: 20, letterSpacing: -0.28 },
  "body-sm-strong": { fontFamily: "sans", fontSize: 14, fontWeight: 500, lineHeight: 20, letterSpacing: -0.28 },
  caption: { fontFamily: "sans", fontSize: 12, fontWeight: 400, lineHeight: 16, letterSpacing: 0 },
  "caption-mono": { fontFamily: "mono", fontSize: 12, fontWeight: 400, lineHeight: 16, letterSpacing: 0 },
  code: { fontFamily: "mono", fontSize: 13, fontWeight: 400, lineHeight: 20, letterSpacing: 0 },
  "button-md": { fontFamily: "sans", fontSize: 14, fontWeight: 500, lineHeight: 20, letterSpacing: 0 },
  "button-lg": { fontFamily: "sans", fontSize: 16, fontWeight: 500, lineHeight: 24, letterSpacing: 0 },
} as const satisfies Record<string, TypeStyle>;

export type TypographyName = keyof typeof typography;

export const radius = {
  none: 0,
  xs: 4,
  sm: 6,
  md: 8,
  lg: 12,
  xl: 16,
  "pill-sm": 64,
  pill: 100,
  full: 9999,
} as const;

export type RadiusName = keyof typeof radius;

/** 4px base unit (`--geist-space`); every value is a multiple of 4. */
export const spacing = {
  xxs: 4,
  xs: 8,
  sm: 12,
  md: 16,
  lg: 24,
  xl: 32,
  "2xl": 40,
  "3xl": 48,
  "4xl": 64,
  "5xl": 96,
  "6xl": 128,
  section: 192,
} as const;

export type SpacingName = keyof typeof spacing;

/** Stacked shadows; every elevated level also carries the inset hairline ring. */
export const elevation = {
  "level-0": { light: "none", ring: false },
  "level-1": { light: "", ring: true },
  "level-2": { light: "0px 1px 1px #00000005, 0px 2px 2px #0000000a", ring: true },
  "level-3": { light: "0px 2px 2px #0000000a, 0px 8px 8px -8px #0000000a", ring: true },
  "level-4": { light: "0px 2px 2px #0000000a, 0px 8px 16px -4px #0000000a", ring: true },
  "level-5": {
    light: "0px 1px 1px #00000005, 0px 8px 16px -4px #0000000a, 0px 24px 32px -8px #0000000f",
    ring: true,
  },
} as const;

export type ElevationName = keyof typeof elevation;

export const hairlineRing = "inset 0 0 0 1px #00000014";

export const breakpoints = {
  tablet: 600,
  desktop: 960,
  wide: 1200,
  ultra: 1400,
} as const;

export const containers = {
  page: 1400,
  legacy: 1200,
} as const;

/** `xs` is the 28px nav CTA; sm/md/lg are `--geist-form-*-height`. */
export const controlHeights = {
  xs: 28,
  sm: 32,
  md: 40,
  lg: 48,
} as const;
