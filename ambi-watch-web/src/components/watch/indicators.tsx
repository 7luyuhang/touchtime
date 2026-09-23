import { cx } from "@/lib/cx";

/** 72×8 bar, 13px above the bottom edge (03, 06). */
export function HomeIndicator({ className }: { className?: string }) {
  return (
    <div
      aria-hidden
      className={cx(
        "absolute bottom-[13px] left-1/2 z-20 h-watch-home-indicator-h w-watch-home-indicator-w -translate-x-1/2 rounded-full bg-watch-home-indicator",
        className,
      )}
    />
  );
}

export interface PageIndicatorProps {
  count: number;
  active: number;
  onSelect?: (index: number) => void;
  className?: string;
}

/** Vertical dots on the crown side: 12px active, 8px inactive, 25px pitch (06). */
export function PageIndicator({ count, active, onSelect, className }: PageIndicatorProps) {
  const dot = (i: number) => (
    <span
      className={cx(
        "block rounded-full transition-all duration-(--watch-motion-duration)",
        i === active ? "size-[12px] bg-watch-white" : "size-[8px] bg-watch-dot-inactive",
      )}
    />
  );
  return (
    <div
      role={onSelect ? "tablist" : "img"}
      aria-orientation={onSelect ? "vertical" : undefined}
      aria-label={onSelect ? undefined : `Page ${active + 1} of ${count}`}
      className={cx("absolute z-20 flex w-[12px] flex-col items-center", className)}
    >
      {Array.from({ length: count }, (_, i) =>
        onSelect ? (
          <button
            key={i}
            type="button"
            role="tab"
            aria-selected={i === active}
            aria-label={`Page ${i + 1}`}
            onClick={() => onSelect(i)}
            className="flex h-[25px] w-[12px] items-center justify-center"
          >
            {dot(i)}
          </button>
        ) : (
          <span key={i} className="flex h-[25px] w-[12px] items-center justify-center">
            {dot(i)}
          </span>
        ),
      )}
    </div>
  );
}

export interface ScrollIndicatorProps {
  /** 0–1 scroll position. */
  progress: number;
  className?: string;
}

/** 10×90 track with a 30px thumb (02 right). */
export function ScrollIndicator({ progress, className }: ScrollIndicatorProps) {
  const clamped = Math.min(Math.max(progress, 0), 1);
  return (
    <div aria-hidden className={cx("absolute z-20 h-[90px] w-[10px] rounded-full bg-watch-scroll-track", className)}>
      <div
        className="absolute left-0 h-[30px] w-[10px] rounded-full bg-watch-white"
        style={{ top: clamped * 60 }}
      />
    </div>
  );
}
