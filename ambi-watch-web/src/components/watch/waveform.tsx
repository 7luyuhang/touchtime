import { useId } from "react";
import { cx } from "@/lib/cx";
import { StopGlyph } from "./watch-icons";

/** Stepped bars in screen px (01 right): [x0, x1, halfHeight] around y = 420.5. */
const STEPS: Array<[number, number, number]> = [
  [81, 110, 10],
  [110, 142, 15],
  [142, 174, 10],
  [174, 206, 40],
  [206, 238, 25],
  [238, 271, 16],
  [271, 300, 10.5],
];
const MID = 420.5;

export interface ListeningWaveformProps {
  onStop?: () => void;
  className?: string;
}

/** Live-capture waveform that fades in from the left and ends in a stop button. */
export function ListeningWaveform({ onStop, className }: ListeningWaveformProps) {
  const fadeId = useId();
  return (
    <div className={cx("absolute inset-0", className)}>
      <svg className="absolute inset-0" width={410} height={502} aria-hidden>
        <defs>
          <linearGradient id={fadeId} x1="40" x2="132" y1="0" y2="0" gradientUnits="userSpaceOnUse">
            <stop offset="0" stopColor="var(--color-watch-waveform)" stopOpacity={0} />
            <stop offset="1" stopColor="var(--color-watch-waveform)" />
          </linearGradient>
        </defs>
        <g fill={`url(#${fadeId})`}>
          <rect x={44} y={MID - 2} width={42} height={4} rx={2} />
          {STEPS.map(([x0, x1, half]) => (
            <rect key={x0} x={x0} y={MID - half} width={x1 - x0 + 1} height={half * 2} rx={4} />
          ))}
        </g>
      </svg>
      <button
        type="button"
        aria-label="Stop listening"
        onClick={onStop}
        className="absolute left-[291px] top-[381px] flex size-[78px] items-center justify-center rounded-full border-2 border-watch-mint-rim bg-watch-mint-deep watch-press"
      >
        <StopGlyph size={28} radius={7} className="text-watch-white" />
      </button>
    </div>
  );
}
