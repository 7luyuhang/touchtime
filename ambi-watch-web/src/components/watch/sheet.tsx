import { useId, type ReactNode } from "react";
import { cx } from "@/lib/cx";
import { sheetPath } from "./geometry";

export interface SheetProps {
  /** Screen-space top and bottom edges of the front sheet. */
  top: number;
  bottom: number;
  radiusTop?: number;
  radiusBottom?: number;
  /** Screen y of the indicator the right edge bows around; omit for a plain sheet. */
  notchCenter?: number;
  /** Cards peeking out behind the front sheet, 8px apart. */
  stack?: { count: number; direction: "up" | "down" };
  header?: { height: number; content: ReactNode };
  children?: ReactNode;
  className?: string;
}

const WIDTH = 410;
const NOTCH = { depth: 33, half: 135 };
const LAYER_GAP = 8;

/** Full-width sheet with a concave right edge and optional stacked layers (02 quick todo, 06 recaps). */
export function Sheet({
  top,
  bottom,
  radiusTop = 96,
  radiusBottom = 64,
  notchCenter,
  stack,
  header,
  children,
  className,
}: SheetProps) {
  const id = useId();
  const height = bottom - top;
  const layers = stack?.count ?? 0;
  const pathFor = (offset: number) =>
    sheetPath({
      width: WIDTH,
      height,
      radiusTop,
      radiusBottom,
      notch: notchCenter === undefined ? undefined : { ...NOTCH, center: notchCenter - top - offset },
    });
  const front = pathFor(0);
  const offsets = Array.from({ length: layers }, (_, i) => (stack?.direction === "up" ? -1 : 1) * LAYER_GAP * (layers - i));
  const frontBackground = header
    ? `var(--gradient-watch-sheet-header) top / 100% ${header.height}px no-repeat, var(--gradient-watch-sheet)`
    : "var(--gradient-watch-sheet)";

  const edge = (key: string | number) => (
    <defs>
      <linearGradient id={`${id}-edge-${key}`} x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stopColor="rgba(255,255,255,0.28)" />
        <stop offset="0.5" stopColor="rgba(255,255,255,0.1)" />
        <stop offset="1" stopColor="rgba(160,220,195,0.45)" />
      </linearGradient>
    </defs>
  );

  return (
    <div className={cx("absolute left-0", className)} style={{ top, width: WIDTH, height }}>
      {offsets.map((offset) => {
        const d = pathFor(offset);
        return (
          <div key={offset} className="absolute inset-0" style={{ transform: `translateY(${offset}px)` }}>
            <div className="absolute inset-0" style={{ clipPath: `path("${d}")`, background: "var(--gradient-watch-sheet)" }} />
            <svg className="pointer-events-none absolute inset-0 overflow-visible" width={WIDTH} height={height} aria-hidden>
              {edge(offset)}
              <path d={d} fill="none" stroke={`url(#${id}-edge-${offset})`} strokeWidth={1.5} />
            </svg>
          </div>
        );
      })}
      <div className="absolute inset-0" style={{ clipPath: `path("${front}")`, background: frontBackground }} />
      <svg className="pointer-events-none absolute inset-0 overflow-visible" width={WIDTH} height={height} aria-hidden>
        {edge("front")}
        {header && (
          <line
            x1="0"
            x2={WIDTH - NOTCH.depth}
            y1={header.height}
            y2={header.height}
            stroke="rgba(255,255,255,0.1)"
            strokeWidth={1.5}
          />
        )}
        <path d={front} fill="none" stroke={`url(#${id}-edge-front)`} strokeWidth={1.5} />
      </svg>
      {header && (
        <div className="absolute inset-x-0 top-0 flex items-center justify-center" style={{ height: header.height }}>
          {header.content}
        </div>
      )}
      <div className="absolute inset-0">{children}</div>
    </div>
  );
}
