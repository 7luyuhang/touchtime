import type { SVGProps } from "react";

export type IconName = "arrow-right" | "arrow-up-right" | "plus" | "close" | "check";

const paths: Record<IconName, string> = {
  "arrow-right": "M3 8h10M9 4l4 4-4 4",
  "arrow-up-right": "M5 11l6-6M6 5h5v5",
  plus: "M8 3v10M3 8h10",
  close: "M4 4l8 8M12 4l-8 8",
  check: "M3 8.5l3 3 7-7",
};

export interface IconProps extends Omit<SVGProps<SVGSVGElement>, "children"> {
  name: IconName;
  size?: number;
}

/** 16px stroke glyphs drawn in `currentColor`; decorative unless labelled. */
export function Icon({ name, size = 16, ...props }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 16 16"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.5}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden={props["aria-label"] ? undefined : true}
      {...props}
    >
      <path d={paths[name]} />
    </svg>
  );
}
