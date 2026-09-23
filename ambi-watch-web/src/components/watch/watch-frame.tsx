import Image from "next/image";
import type { ReactNode } from "react";
import { cx } from "@/lib/cx";

/** Device mockup (07) cropped to its body; the screen cutout sits at (41, 190) at 1×. */
const FRAME = { width: 488, height: 882, screenX: 41, screenY: 190 } as const;

export interface WatchFrameProps {
  children?: ReactNode;
  caption?: ReactNode;
  scale?: number;
  className?: string;
  priority?: boolean;
}

/** Renders a `WatchScreen` inside the device mockup; the frame never blocks pointer input. */
export function WatchFrame({ children, caption, scale = 1, className, priority = false }: WatchFrameProps) {
  return (
    <figure className={cx("inline-flex flex-col items-center gap-sm", className)}>
      <div className="relative shrink-0" style={{ width: FRAME.width * scale, height: FRAME.height * scale }}>
        <div
          className="absolute left-0 top-0 origin-top-left"
          style={{ width: FRAME.width, height: FRAME.height, transform: scale === 1 ? undefined : `scale(${scale})` }}
        >
          <div className="absolute" style={{ left: FRAME.screenX, top: FRAME.screenY }}>
            {children}
          </div>
          <Image
            src="/watch/ambi-watch-frame@2x.png"
            alt=""
            width={FRAME.width}
            height={FRAME.height}
            priority={priority}
            draggable={false}
            className="pointer-events-none absolute inset-0 select-none"
          />
        </div>
      </div>
      {caption && <figcaption className="font-mono text-caption-mono text-mute">{caption}</figcaption>}
    </figure>
  );
}
