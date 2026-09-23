import { useId, type CSSProperties, type ReactNode } from "react";
import { cx } from "@/lib/cx";

export type GlassStroke = "glass" | "mint" | "red" | "flat" | "none";
export type GlassFill = "glass" | "thin" | "dark" | "none";

const strokeStops: Record<Exclude<GlassStroke, "none">, Array<[number, string]>> = {
  glass: [
    [0, "rgba(255,255,255,0.26)"],
    [0.5, "rgba(255,255,255,0.05)"],
    [1, "rgba(255,255,255,0.12)"],
  ],
  mint: [
    [0, "rgba(102,177,150,0.9)"],
    [0.55, "rgba(93,180,147,0.35)"],
    [1, "rgba(93,180,147,0.6)"],
  ],
  red: [
    [0, "rgba(251,119,96,0.9)"],
    [0.55, "rgba(218,82,72,0.35)"],
    [1, "rgba(218,82,72,0.8)"],
  ],
  flat: [
    [0, "rgba(255,255,255,0.25)"],
    [1, "rgba(255,255,255,0.25)"],
  ],
};

/** No backdrop blur: Chrome drops the clip-path when both sit under a transformed ancestor. */
const fills: Record<GlassFill, CSSProperties> = {
  glass: { background: "var(--watch-glass-fill)" },
  thin: { background: "var(--watch-glass-fill-thin)" },
  dark: { background: "var(--watch-glass-fill-dark)" },
  none: {},
};

export interface GlassShapeProps {
  /** SVG path in the shape's local coordinates (0,0 at the top-left of width×height). */
  d: string;
  width: number;
  height: number;
  fill?: GlassFill;
  fillStyle?: CSSProperties;
  stroke?: GlassStroke;
  strokeWidth?: number;
  className?: string;
  style?: CSSProperties;
  children?: ReactNode;
}

/** A free-form glass surface: clipped translucent fill plus a gradient hairline. */
export function GlassShape({
  d,
  width,
  height,
  fill = "glass",
  fillStyle,
  stroke = "glass",
  strokeWidth = 1.5,
  className,
  style,
  children,
}: GlassShapeProps) {
  const gradientId = useId();
  return (
    <div className={cx("absolute", className)} style={{ width, height, ...style }}>
      <div className="absolute inset-0" style={{ clipPath: `path("${d}")`, ...fills[fill], ...fillStyle }} />
      {stroke !== "none" && (
        <svg className="pointer-events-none absolute inset-0 overflow-visible" width={width} height={height} aria-hidden>
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              {strokeStops[stroke].map(([offset, color]) => (
                <stop key={offset} offset={offset} stopColor={color} />
              ))}
            </linearGradient>
          </defs>
          <path d={d} fill="none" stroke={`url(#${gradientId})`} strokeWidth={strokeWidth} />
        </svg>
      )}
      {children}
    </div>
  );
}
