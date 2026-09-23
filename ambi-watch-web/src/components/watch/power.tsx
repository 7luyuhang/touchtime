"use client";

import { useRef, useState, type PointerEvent } from "react";
import { cx } from "@/lib/cx";
import { gooeyPath, type Circle } from "./geometry";
import { GlassShape } from "./glass-shape";
import { BackTriangleGlyph, ChevronDownGlyph, PowerGlyph } from "./watch-icons";

/** Vertical slide-to-power-off (05 step 1): 192×376 track, 160px knob. */
const TRACK = { left: 110, top: 63, width: 192, height: 376 } as const;
const KNOB = 160;
const KNOB_INSET = 16;
const TRAVEL = TRACK.height - KNOB - KNOB_INSET * 2;

export interface PowerSliderProps {
  onComplete?: () => void;
}

export function PowerSlider({ onComplete }: PowerSliderProps) {
  const [offset, setOffset] = useState(0);
  const [dragging, setDragging] = useState(false);
  const origin = useRef<number | null>(null);

  const onPointerDown = (event: PointerEvent<HTMLButtonElement>) => {
    event.currentTarget.setPointerCapture(event.pointerId);
    origin.current = event.clientY - offset;
    setDragging(true);
  };
  const onPointerMove = (event: PointerEvent<HTMLButtonElement>) => {
    if (origin.current === null) return;
    const rect = event.currentTarget.getBoundingClientRect();
    const scale = rect.height / KNOB || 1;
    setOffset(Math.min(Math.max((event.clientY - origin.current) / scale, 0), TRAVEL));
  };
  const onPointerUp = () => {
    origin.current = null;
    setDragging(false);
    if (offset > TRAVEL * 0.7) {
      setOffset(TRAVEL);
      onComplete?.();
    } else {
      setOffset(0);
    }
  };

  return (
    <>
      <div
        className="absolute rounded-full watch-glass"
        style={{ left: TRACK.left, top: TRACK.top, width: TRACK.width, height: TRACK.height }}
      />
      <div className="pointer-events-none absolute left-[179px] flex flex-col gap-[31px]" style={{ top: 279 }}>
        {[0.35, 0.28, 0.18].map((opacity) => (
          <ChevronDownGlyph key={opacity} style={{ opacity }} className="text-watch-white" />
        ))}
      </div>
      <button
        type="button"
        aria-label="Slide down to power off"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onKeyDown={(event) => {
          if (event.key === "Enter" || event.key === " " || event.key === "ArrowDown") {
            event.preventDefault();
            onComplete?.();
          }
        }}
        className={cx(
          "absolute flex touch-none items-center justify-center rounded-full bg-watch-power-muted text-watch-white watch-stroke watch-stroke-red",
          !dragging && "transition-transform duration-(--watch-motion-duration) ease-watch",
        )}
        style={{ left: 126, top: 79, width: KNOB, height: KNOB, transform: `translateY(${offset}px)` }}
      >
        <PowerGlyph />
      </button>
    </>
  );
}

export type PowerPairLayout = "armed" | "hint" | "horizontal";

const layouts: Record<PowerPairLayout, { back: Circle; ring: Circle; fillet: number }> = {
  armed: { back: { cx: 205, cy: 162, r: 95 }, ring: { cx: 205, cy: 338, r: 95 }, fillet: 12.8 },
  hint: { back: { cx: 206, cy: 115, r: 80 }, ring: { cx: 205, cy: 274, r: 95 }, fillet: 12 },
  horizontal: { back: { cx: 115, cy: 384, r: 95 }, ring: { cx: 294, cy: 384, r: 95 }, fillet: 7 },
};

export interface PowerPairProps {
  layout: PowerPairLayout;
  onBack?: () => void;
  onHoldStart?: () => void;
  onHoldEnd?: () => void;
  holding?: boolean;
}

/** Back circle merged with the ring around the armed power knob (05 steps 2–4). */
export function PowerPair({ layout, onBack, onHoldStart, onHoldEnd, holding = false }: PowerPairProps) {
  const { back, ring, fillet } = layouts[layout];
  const path = gooeyPath([back, ring], fillet);
  return (
    <>
      <GlassShape d={path} width={410} height={502} className="left-0 top-0" />
      <button
        type="button"
        aria-label="Cancel"
        onClick={onBack}
        className="absolute flex items-center justify-center rounded-full text-watch-white watch-press"
        style={{ left: back.cx - back.r, top: back.cy - back.r, width: back.r * 2, height: back.r * 2 }}
      >
        <BackTriangleGlyph className="-translate-x-[4px]" />
      </button>
      <button
        type="button"
        aria-label="Press and hold to power off"
        onPointerDown={onHoldStart}
        onPointerUp={onHoldEnd}
        onPointerLeave={onHoldEnd}
        onPointerCancel={onHoldEnd}
        className={cx(
          "absolute flex touch-none items-center justify-center rounded-full bg-watch-power text-watch-white watch-stroke watch-stroke-red",
          "transition-transform duration-(--watch-motion-hold-duration) ease-linear",
          holding && "scale-90",
        )}
        style={{ left: ring.cx - KNOB / 2, top: ring.cy - KNOB / 2, width: KNOB, height: KNOB }}
      >
        <PowerGlyph />
      </button>
    </>
  );
}
