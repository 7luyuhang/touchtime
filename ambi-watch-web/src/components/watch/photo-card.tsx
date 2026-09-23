import Image from "next/image";
import { cx } from "@/lib/cx";

/** 198×300 photo with 26px corners (03 right). */
export function PhotoCard({ src, alt, className }: { src: string; alt: string; className?: string }) {
  return (
    <Image
      src={src}
      alt={alt}
      width={198}
      height={300}
      className={cx("h-[300px] w-[198px] rounded-watch-photo object-cover", className)}
    />
  );
}
