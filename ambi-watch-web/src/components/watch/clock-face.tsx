import type { ReactNode } from "react";

/** Only 0, 1 and 9 appear in the references (10:09); other numerals are not drawn yet. */
export type ClockDigit = "0" | "1" | "9";

/**
 * Glyphs on a 40px module inside a 124×164 cell; paths are stroke centre-lines
 * (4px stroke, so the outer edge lands on the cell bounds). Measured from 01.
 */
const glyphs: Record<ClockDigit, ReactNode> = {
  "0": (
    <>
      <circle cx="62" cy="22" r="20" />
      <circle cx="62" cy="142" r="20" />
      <rect x="2" y="42" width="40" height="80" rx="20" />
      <rect x="82" y="42" width="40" height="80" rx="20" />
    </>
  ),
  "1": (
    <path d="M12 2H72A10 10 0 0 1 82 12V116A6 6 0 0 0 88 122H112A10 10 0 0 1 122 132V152A10 10 0 0 1 112 162H12A10 10 0 0 1 2 152V132A10 10 0 0 1 12 122H36A6 6 0 0 0 42 116V48A6 6 0 0 0 36 42H12A10 10 0 0 1 2 32V12A10 10 0 0 1 12 2Z" />
  ),
  "9": (
    <>
      <path d="M12 2H112A10 10 0 0 1 122 12V152A10 10 0 0 1 112 162H92A10 10 0 0 1 82 152V128A6 6 0 0 0 76 122H12A10 10 0 0 1 2 112V12A10 10 0 0 1 12 2Z" />
      <rect x="42" y="42" width="40" height="40" rx="8" />
    </>
  ),
};

const CELL = { width: 124, height: 164 };
const GAP = 13;

export interface OutlineClockProps {
  hours: [ClockDigit, ClockDigit];
  minutes: [ClockDigit, ClockDigit];
  /** Rendered cell width in px; 124 on the face (01 left), 94 while listening (01 right). */
  cellWidth?: number;
  className?: string;
}

/** Stacked outline numerals: hours on top, minutes below, 13px gaps. */
export function OutlineClock({ hours, minutes, cellWidth = CELL.width, className }: OutlineClockProps) {
  const k = cellWidth / CELL.width;
  const cellHeight = CELL.height * k;
  const width = cellWidth * 2 + GAP;
  const height = cellHeight * 2 + GAP;
  const digits = [...hours, ...minutes];
  return (
    <svg
      width={width}
      height={height}
      viewBox={`0 0 ${width} ${height}`}
      className={className}
      role="img"
      aria-label={`${hours.join("")}:${minutes.join("")}`}
    >
      {digits.map((digit, i) => (
        <g
          key={i}
          transform={`translate(${(i % 2) * (cellWidth + GAP)} ${Math.floor(i / 2) * (cellHeight + GAP)}) scale(${k})`}
          fill="none"
          stroke="currentColor"
          strokeWidth={4}
        >
          {glyphs[digit]}
        </g>
      ))}
    </svg>
  );
}
