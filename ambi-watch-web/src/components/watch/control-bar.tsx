import type { ReactNode } from "react";
import { cx } from "@/lib/cx";
import { gooeyPath } from "./geometry";
import { GlassShape } from "./glass-shape";
import { PlusGlyph, RecordGlyph, StopGlyph } from "./watch-icons";

/** Three 102px circles on a 105px pitch, joined by 38px necks (03). */
const CAPTURE = { left: 48, top: 349, width: 314, height: 104, r: 51, pitch: 105 } as const;
const capturePath = gooeyPath(
  [0, 1, 2].map((i) => ({ cx: CAPTURE.r + 1 + i * CAPTURE.pitch, cy: CAPTURE.r + 1, r: CAPTURE.r })),
  8,
);

export interface CaptureControlBarProps {
  dimmed?: boolean;
  recording?: boolean;
  onRecord?: () => void;
  onStop?: () => void;
  onAdd?: () => void;
}

export function CaptureControlBar({ dimmed = false, recording = false, onRecord, onStop, onAdd }: CaptureControlBarProps) {
  const buttons: Array<{ label: string; icon: ReactNode; onClick?: () => void }> = [
    { label: recording ? "Recording" : "Record", icon: <RecordGlyph className="text-watch-red" />, onClick: onRecord },
    { label: "Stop", icon: <StopGlyph className="text-watch-white" />, onClick: onStop },
    { label: "Add", icon: <PlusGlyph className="text-watch-white" />, onClick: onAdd },
  ];
  return (
    <GlassShape
      d={capturePath}
      width={CAPTURE.width}
      height={CAPTURE.height}
      className={cx("z-10 transition-opacity duration-(--watch-motion-duration)", dimmed && "opacity-35")}
      style={{ left: CAPTURE.left, top: CAPTURE.top }}
    >
      {buttons.map((button, i) => (
        <button
          key={button.label}
          type="button"
          aria-label={button.label}
          aria-pressed={i === 0 ? recording : undefined}
          onClick={button.onClick}
          disabled={dimmed}
          className="absolute flex items-center justify-center rounded-full watch-press"
          style={{ left: 1 + i * CAPTURE.pitch, top: 1, width: CAPTURE.r * 2, height: CAPTURE.r * 2 }}
        >
          <span className={cx(i === 0 && recording && "animate-pulse")}>{button.icon}</span>
        </button>
      ))}
    </GlassShape>
  );
}

/**
 * Two pill segments pinched together in the middle (06 listening).
 * Local coordinates; the bar spans x 18–392, y 342–468 on screen.
 */
const SPLIT = { left: 17, top: 341, width: 376, height: 128 } as const;
const splitPath = [
  "M 64 1 H 161 A 20 20 0 0 1 181 21 V 37 A 7 7 0 0 0 195 37 V 21 A 20 20 0 0 1 215 1 H 312",
  "A 63 63 0 0 1 312 127 H 215 A 20 20 0 0 1 195 107 V 91 A 7 7 0 0 0 181 91 V 107 A 20 20 0 0 1 161 127 H 64",
  "A 63 63 0 0 1 64 1 Z",
].join(" ");

export function SplitControlBar({ onStop, onAdd }: { onStop?: () => void; onAdd?: () => void }) {
  return (
    <GlassShape
      d={splitPath}
      width={SPLIT.width}
      height={SPLIT.height}
      fill="dark"
      stroke="flat"
      className="z-10"
      style={{ left: SPLIT.left, top: SPLIT.top }}
    >
      <button
        type="button"
        aria-label="Stop listening"
        onClick={onStop}
        className="absolute left-0 top-0 flex h-full w-[188px] items-center justify-center watch-press"
      >
        <StopGlyph size={48} radius={10} className="text-watch-red" />
      </button>
      <button
        type="button"
        aria-label="Add"
        onClick={onAdd}
        className="absolute right-0 top-0 flex h-full w-[188px] items-center justify-center watch-press"
      >
        <PlusGlyph size={46} className="text-watch-white" />
      </button>
    </GlassShape>
  );
}
