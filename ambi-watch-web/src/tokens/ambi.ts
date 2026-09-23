import type { AmbiToken, AmbiTokenStatus, AmbiTypeToken, TypeStyle } from "./types";

/**
 * ambi watch layer, measured from the reference images at the canonical
 * 410×502 px screen (= 205×251 pt @2x). Every px value is in screen pixels.
 * Sources: 01 watch face · 02 quick actions · 03 capture · 04 capture home ·
 * 05 power off · 06 listening/recaps · 07 device mockup.
 */

function token(status: AmbiTokenStatus, value: string, source: string, note?: string): AmbiToken {
  return { value, status, source, note };
}
const sampled = (value: string, source: string, note?: string) => token("sampled", value, source, note);
const assumed = (value: string, source: string, note?: string) => token("assumed", value, source, note);

export const watchScreen = {
  width: sampled("410px", "07", "Mockup cutout is 820×1004 at 2×"),
  height: sampled("502px", "07"),
  radius: sampled("100px", "07", "Continuous-corner cutout; circular fit ≈ 100px"),
  "status-bar": sampled("92px", "06", "Annotated as 46 (pt); 92px on the 410×502 canvas"),
  inset: sampled("8px", "02", "List cards sit 8px from the screen edge"),
  gutter: sampled("32px", "02 · 05", "Close button and header text inset"),
} satisfies Record<string, AmbiToken>;

export const ambiColors = {
  "watch-black": sampled("#000000", "01"),
  "watch-white": sampled("#ffffff", "01"),
  "watch-label-secondary": sampled("rgba(255, 255, 255, 0.55)", "02 · 06", "#8e9a96 over #17231f"),
  "watch-label-dim": sampled("rgba(255, 255, 255, 0.3)", "01", "Clock digits while listening"),
  "watch-mint": sampled("#55aa8c", "02", "“Quick Actions” header"),
  "watch-mint-rim": sampled("#5db493", "01 · 03", "Camera and stop button rims"),
  "watch-mint-deep": sampled("#2d5a4a", "01", "Stop button fill"),
  "watch-red": sampled("#ff383c", "03 · 06", "Record dot, stop square"),
  "watch-power": sampled("#ef4437", "05", "Power knob, armed"),
  "watch-power-muted": sampled("#bc3b31", "05", "Power knob on the slider"),
  "watch-power-rim": sampled("#fb7760", "05", "Knob top highlight"),
  "watch-card-light": sampled("#f2f3f3", "02", "Notification card"),
  "watch-card-light-label": sampled("#000000", "02"),
  "watch-card-light-secondary": sampled("#797979", "02"),
  "watch-waveform": sampled("#98a9a3", "01"),
  "watch-home-indicator": sampled("rgba(255, 255, 255, 0.27)", "03 · 06", "#4f4f4f over #0e0e0e"),
  "watch-dot-inactive": sampled("#404040", "06"),
  "watch-scroll-track": sampled("#333333", "02"),
} satisfies Record<string, AmbiToken>;

export const ambiGradients = {
  ambient: sampled(
    "linear-gradient(180deg, #000000 0%, #020403 20%, #070f0c 40%, #0b1612 50%, #12231d 60%, #223730 70%, #28443a 80%, #305246 90%, #33594b 100%)",
    "01 · 02 · 06",
    "Black fading to deep green; used by listening, quick actions, recaps",
  ),
  capture: sampled(
    "linear-gradient(180deg, #264a3d 0%, #23463a 10%, #1c382e 20%, #182e26 30%, #11201b 40%, #0c1713 50%, #09100e 60%, #0e1210 70%, #111211 80%, #0d0d0d 90%, #0a0a0a 100%)",
    "03",
  ),
  aurora: sampled(
    "radial-gradient(90% 34% at 50% 60%, rgba(76, 96, 128, 0.95) 0%, rgba(60, 82, 104, 0.6) 45%, rgba(40, 60, 70, 0) 100%), linear-gradient(180deg, #1a362c 0%, #1e3e33 22%, #23443c 34%, #30505a 46%, #34465c 58%, #242a3a 70%, #191a23 80%, #0d0d0f 90%, #08080a 100%)",
    "04",
    "Green top, blue glow centred near y≈300, dark base; the reference also carries film grain",
  ),
  photo: sampled(
    "linear-gradient(180deg, #333c47 0%, #313a45 10%, #282f37 20%, #1e232a 30%, #16191f 40%, #111417 50%, #0b0d0f 60%, #09090a 70%, #050606 80%, #030303 90%, #000000 100%)",
    "03",
    "Ambient tint behind the photo preview",
  ),
  power: sampled(
    "linear-gradient(180deg, #000000 0%, #080404 20%, #0e0605 30%, #160807 40%, #210b0a 50%, #2e0f0c 60%, #3d1310 70%, #4e1713 80%, #631d18 90%, #6e211b 95%, #7e2822 100%)",
    "05",
  ),
  sheet: sampled(
    "linear-gradient(180deg, #161e1b 0%, #1d2c26 25%, #253e35 50%, #2c4b40 70%, #345a4c 100%)",
    "02 · 06",
    "Recap and quick-todo sheet body",
  ),
  "sheet-header": sampled("linear-gradient(180deg, #181a1a 0%, #141816 100%)", "06", "Recap time header"),
} satisfies Record<string, AmbiToken>;

export const ambiMaterials = {
  "glass-fill": sampled("rgba(255, 255, 255, 0.08)", "02 · 03 · 05", "Round buttons, control bar"),
  "glass-fill-thin": sampled("rgba(255, 255, 255, 0.05)", "02", "List cards"),
  "glass-fill-dark": sampled("rgba(0, 0, 0, 0.28)", "06", "Listening control bar darkens the scene"),
  "glass-stroke": sampled(
    "linear-gradient(180deg, rgba(255, 255, 255, 0.26) 0%, rgba(255, 255, 255, 0.05) 50%, rgba(255, 255, 255, 0.12) 100%)",
    "02 · 03",
    "Hairline is brightest on top, faint at the sides",
  ),
  "glass-stroke-mint": sampled(
    "linear-gradient(180deg, rgba(102, 177, 150, 0.9) 0%, rgba(93, 180, 147, 0.35) 55%, rgba(93, 180, 147, 0.6) 100%)",
    "03",
    "Camera button rim",
  ),
  "glass-stroke-red": sampled(
    "linear-gradient(180deg, rgba(251, 119, 96, 0.9) 0%, rgba(218, 82, 72, 0.35) 55%, rgba(218, 82, 72, 0.8) 100%)",
    "05",
  ),
  "glass-blur": assumed("16px", "03", "Now-playing pill softens the wave behind it; exact blur unknown"),
} satisfies Record<string, AmbiToken>;

export const ambiRadii = {
  screen: sampled("100px", "07"),
  sheet: sampled("96px", "02 · 06", "Quick-todo and recap sheets"),
  card: sampled("40px", "02", "Notification card"),
  photo: sampled("26px", "03"),
  art: sampled("16px", "03", "Album art"),
  "app-icon": sampled("12px", "02", "48px app icon; 14px at 56px"),
  glyph: sampled("10px", "03 · 06", "Stop square"),
} satisfies Record<string, AmbiToken>;

export const ambiSizes = {
  "button-sm": sampled("80px", "02 · 05", "Close button (40pt)"),
  "button-lg": sampled("102px", "03", "Camera and control-bar buttons (51pt)"),
  knob: sampled("160px", "05"),
  ring: sampled("190px", "05"),
  "list-card": sampled("110px", "02", "Pill list card height; 10px gap"),
  "app-icon": sampled("48px", "02"),
  "app-icon-lg": sampled("56px", "02"),
  glyph: sampled("40px", "03", "Record dot / stop square"),
  "glyph-lg": sampled("48px", "06"),
  "home-indicator-w": sampled("72px", "03"),
  "home-indicator-h": sampled("8px", "03"),
} satisfies Record<string, AmbiToken>;

export const ambiMotion = {
  duration: assumed("320ms", "—", "No motion in the stills; iOS-like default"),
  easing: assumed("cubic-bezier(0.32, 0.72, 0, 1)", "—", "Spring-like ease-out"),
  "press-scale": assumed("0.96", "—"),
  "hold-duration": assumed("900ms", "05", "“Press & hold to power off”"),
} satisfies Record<string, AmbiToken>;

function type(style: TypeStyle, status: AmbiTokenStatus, source: string, note?: string): AmbiTypeToken {
  return { ...style, status, source, note };
}

export const ambiTypography = {
  "watch-time": type(
    { fontFamily: "watch", fontSize: 32, fontWeight: 500, lineHeight: 40, letterSpacing: 1 },
    "sampled",
    "02 · 06",
    "Digit height 23px → 32px (16pt); “10:09” is 85px wide",
  ),
  "watch-title": type(
    { fontFamily: "watch", fontSize: 32, fontWeight: 400, lineHeight: 40, letterSpacing: 1 },
    "sampled",
    "02 · 03",
    "Cap height 23px → 32px (16pt); tracking fitted to six label widths",
  ),
  "watch-title-strong": type(
    { fontFamily: "watch", fontSize: 32, fontWeight: 600, lineHeight: 46, letterSpacing: 0.9 },
    "sampled",
    "06",
    "Recap title; 46px line pitch, widths fit 32px semibold",
  ),
  "watch-body": type(
    { fontFamily: "watch", fontSize: 28, fontWeight: 400, lineHeight: 40, letterSpacing: 1.1 },
    "sampled",
    "02 · 05 · 06",
    "Cap height 20px → 28px (14pt), 40px line pitch; tracking fitted to eight widths",
  ),
  "watch-header": type(
    { fontFamily: "watch-serif", fontSize: 33, fontWeight: 400, lineHeight: 40, letterSpacing: 0 },
    "sampled",
    "02",
    "Cap height 24px, 205px wide in Marcellus; the face reads as Optima",
  ),
} satisfies Record<string, AmbiTypeToken>;

export const ambiFontStacks = {
  watch: assumed(
    'var(--font-inter), -apple-system, "SF Pro Text", system-ui, sans-serif',
    "02 · 06",
    "Reads as SF Pro. Inter comes first so the fitted tracking renders the same everywhere; with SF Pro, drop tracking to ~0",
  ),
  "watch-serif": assumed(
    'var(--font-marcellus), Optima, serif',
    "02",
    "Reads as Optima; Marcellus is the closest open face and is sized to the reference",
  ),
} satisfies Record<string, AmbiToken>;

export const ambiTokenGroups = {
  Screen: { prefix: "--watch-screen-", tokens: watchScreen },
  Color: { prefix: "--color-", tokens: ambiColors },
  Gradient: { prefix: "--gradient-watch-", tokens: ambiGradients },
  Material: { prefix: "--watch-", tokens: ambiMaterials },
  Radius: { prefix: "--radius-watch-", tokens: ambiRadii },
  Size: { prefix: "--spacing-watch-", tokens: ambiSizes },
  Motion: { prefix: "--watch-motion-", tokens: ambiMotion },
  "Font stack": { prefix: "--font-", tokens: ambiFontStacks },
} as const;
