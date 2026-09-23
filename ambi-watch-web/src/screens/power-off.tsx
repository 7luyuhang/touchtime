"use client";

import { useEffect, useRef, useState } from "react";
import {
  BackTriangleGlyph,
  CloseButton,
  PowerPair,
  PowerSlider,
  RoundButton,
  WatchScreen,
} from "@/components/watch";

export type PowerStep = 1 | 2 | 3 | 4;

const HOLD_MS = 900;
const SETTLE_MS = 700;

export interface PowerOffScreenProps {
  initialStep?: PowerStep;
  step?: PowerStep;
  onStepChange?: (step: PowerStep) => void;
}

/**
 * 05 power-off flow. Drag the knob down (step 1) → the pair arms (2) and
 * settles with the hint (3) → press and hold the knob (4). Close or the back
 * triangle returns to step 1.
 */
export function PowerOffScreen({ initialStep = 1, step: controlled, onStepChange }: PowerOffScreenProps) {
  const [internal, setInternal] = useState<PowerStep>(initialStep);
  const step = controlled ?? internal;
  const [holding, setHolding] = useState(false);
  const holdTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const settleTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  const go = (next: PowerStep) => {
    setInternal(next);
    onStepChange?.(next);
  };

  useEffect(
    () => () => {
      if (holdTimer.current) clearTimeout(holdTimer.current);
      if (settleTimer.current) clearTimeout(settleTimer.current);
    },
    [],
  );

  const arm = () => {
    go(2);
    settleTimer.current = setTimeout(() => go(3), SETTLE_MS);
  };
  const startHold = () => {
    if (step !== 3) return;
    setHolding(true);
    holdTimer.current = setTimeout(() => {
      setHolding(false);
      go(4);
    }, HOLD_MS);
  };
  const endHold = () => {
    setHolding(false);
    if (holdTimer.current) clearTimeout(holdTimer.current);
  };
  const reset = () => {
    endHold();
    if (settleTimer.current) clearTimeout(settleTimer.current);
    go(1);
  };

  return (
    <WatchScreen background="power" label={`Power off, step ${step}`}>
      <div key={step} className="absolute inset-0 animate-[watch-fade-in_var(--watch-motion-duration)_var(--watch-motion-easing)]">
        {step === 1 && (
          <>
            <PowerSlider onComplete={arm} />
            <div className="absolute left-[298px] top-[388px]">
              <RoundButton
                tone="red"
                label="Cancel"
                onClick={reset}
                icon={<BackTriangleGlyph size={27} className="-translate-x-[2px]" />}
              />
            </div>
          </>
        )}
        {step === 2 && <PowerPair layout="armed" onBack={reset} />}
        {step === 3 && (
          <>
            <PowerPair layout="hint" onBack={reset} onHoldStart={startHold} onHoldEnd={endHold} holding={holding} />
            <p className="absolute inset-x-0 top-[387px] text-center text-watch-body">
              Press &amp; hold to
              <br />
              power off
            </p>
          </>
        )}
        {step === 4 && <PowerPair layout="horizontal" onBack={reset} />}
      </div>
      <CloseButton onClick={reset} className="left-[31px] top-[31px]" />
    </WatchScreen>
  );
}
