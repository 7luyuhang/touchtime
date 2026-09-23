import Image from "next/image";
import { cx } from "@/lib/cx";

export interface NowPlayingPillProps {
  title: string;
  artist: string;
  artwork: string;
  className?: string;
}

/** 376×142 glass pill with 78px artwork (03 middle). */
export function NowPlayingPill({ title, artist, artwork, className }: NowPlayingPillProps) {
  return (
    <div
      className={cx(
        "relative flex h-[142px] w-[376px] items-center gap-[23px] rounded-full pl-[32px] pr-[28px] watch-glass watch-stroke",
        className,
      )}
    >
      <Image
        src={artwork}
        alt=""
        width={78}
        height={78}
        className="size-[78px] shrink-0 rounded-watch-art object-cover"
      />
      <div className="flex min-w-0 flex-col pt-[4px]">
        <p className="truncate text-watch-title">{title}</p>
        <p className="truncate text-watch-body text-watch-label-secondary">{artist}</p>
      </div>
    </div>
  );
}
