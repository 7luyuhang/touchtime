import type { ReactNode } from "react";
import { cx } from "@/lib/cx";

export interface WatchFrameProps {
  children?: ReactNode;
  caption?: ReactNode;
  className?: string;
}

/**
 * Renders a screen at 1:1 watch-face size (`--watch-face-*` tokens) inside the
 * case. Screens compose their content as children of the face.
 */
export function WatchFrame({ children, caption, className }: WatchFrameProps) {
  return (
    <figure className={cx("inline-flex flex-col items-center gap-sm", className)}>
      <div className="rounded-[calc(var(--watch-face-radius)+var(--watch-face-bezel))] bg-watch-case p-(--watch-face-bezel) elevation-4">
        <div className="relative h-(--watch-face-height) w-(--watch-face-width) overflow-hidden rounded-(--watch-face-radius) bg-watch-face text-watch-face-fg">
          {children}
        </div>
      </div>
      {caption && <figcaption className="font-mono text-caption-mono text-mute">{caption}</figcaption>}
    </figure>
  );
}
