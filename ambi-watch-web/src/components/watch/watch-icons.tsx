import { useId, type ReactNode, type SVGProps } from "react";

type GlyphProps = Omit<SVGProps<SVGSVGElement>, "children"> & { size?: number };

function Svg({ size, viewBox, children, ...props }: GlyphProps & { viewBox: string; children: ReactNode }) {
  const [, , w, h] = viewBox.split(" ").map(Number);
  return (
    <svg
      width={size ?? w}
      height={size ? (size * h) / w : h}
      viewBox={viewBox}
      fill="none"
      aria-hidden
      {...props}
    >
      {children}
    </svg>
  );
}

/** 29px cross, 3.5px round stroke (02 close button). */
export function CloseGlyph(props: GlyphProps) {
  return (
    <Svg viewBox="0 0 30 30" {...props}>
      <path d="M2.5 2.5l25 25M27.5 2.5l-25 25" stroke="currentColor" strokeWidth={3.5} strokeLinecap="round" />
    </Svg>
  );
}

/** 42px plus, 3px stroke (03 control bar). */
export function PlusGlyph(props: GlyphProps) {
  return (
    <Svg viewBox="0 0 42 42" {...props}>
      <path d="M21 1.5v39M1.5 21h39" stroke="currentColor" strokeWidth={3} strokeLinecap="round" />
    </Svg>
  );
}

export function RecordGlyph(props: GlyphProps) {
  return (
    <Svg viewBox="0 0 40 40" {...props}>
      <circle cx="20" cy="20" r="20" fill="currentColor" />
    </Svg>
  );
}

export function StopGlyph({ radius = 10, ...props }: GlyphProps & { radius?: number }) {
  return (
    <Svg viewBox="0 0 40 40" {...props}>
      <rect width="40" height="40" rx={radius} fill="currentColor" />
    </Svg>
  );
}

/** 46×42 filled camera (03). */
export function CameraGlyph(props: GlyphProps) {
  return (
    <Svg viewBox="0 0 46 42" {...props}>
      <path
        fillRule="evenodd"
        clipRule="evenodd"
        d="M15.2 3.6A4 4 0 0 1 18.8 1.5h8.4a4 4 0 0 1 3.6 2.1L32.6 7H38a7 7 0 0 1 7 7v19a7 7 0 0 1-7 7H8a7 7 0 0 1-7-7V14a7 7 0 0 1 7-7h5.4l1.8-3.4ZM23 32.5a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z"
        fill="currentColor"
      />
    </Svg>
  );
}

/** 60×62 power symbol, 5.5px stroke (05). */
export function PowerGlyph(props: GlyphProps) {
  return (
    <Svg viewBox="0 0 60 62" {...props}>
      <path
        d="M17.5 12.5A26 26 0 1 0 42.5 12.5M30 3v26"
        stroke="currentColor"
        strokeWidth={5.5}
        strokeLinecap="round"
      />
    </Svg>
  );
}

/** Left-pointing outline triangle (05); 44×50 large, 27×31 small. */
export function BackTriangleGlyph({ strokeWidth = 5, ...props }: GlyphProps & { strokeWidth?: number }) {
  return (
    <Svg viewBox="0 0 44 50" {...props}>
      <path
        d="M41.5 4.2v41.6a1.6 1.6 0 0 1-2.4 1.4L3.8 26.4a1.6 1.6 0 0 1 0-2.8L39.1 2.8a1.6 1.6 0 0 1 2.4 1.4Z"
        stroke="currentColor"
        strokeWidth={strokeWidth}
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** 52×14 chevron, 6px stroke (05 slider hint). */
export function ChevronDownGlyph(props: GlyphProps) {
  return (
    <Svg viewBox="0 0 52 14" {...props}>
      <path d="M3 3l23 8 23-8" stroke="currentColor" strokeWidth={6} strokeLinecap="round" strokeLinejoin="round" />
    </Svg>
  );
}

/** 36px checked box (02 quick todo). */
export function TodoGlyph(props: GlyphProps) {
  return (
    <Svg viewBox="0 0 36 36" {...props}>
      <rect x="1.5" y="1.5" width="33" height="33" rx="8" stroke="currentColor" strokeWidth={3} />
      <path d="M11 18.5l5 5 9-11" stroke="currentColor" strokeWidth={3} strokeLinecap="round" strokeLinejoin="round" />
    </Svg>
  );
}

/** Gmail app icon on its white tile, redrawn as vector. */
export function GmailIcon({ size = 48, radius }: { size?: number; radius?: number }) {
  const id = useId();
  const r = ((radius ?? size * 0.25) * 48) / size;
  return (
    <svg width={size} height={size} viewBox="0 0 48 48" aria-label="Gmail" role="img">
      <defs>
        <linearGradient id={`${id}-l`} gradientUnits="userSpaceOnUse" x1="0" y1="12" x2="0" y2="36">
          <stop offset="0" stopColor="#ff62a8" />
          <stop offset="0.5" stopColor="#ff4545" />
          <stop offset="1" stopColor="#ff3f3a" />
        </linearGradient>
        <linearGradient id={`${id}-v`} gradientUnits="userSpaceOnUse" x1="22" y1="0" x2="38" y2="0">
          <stop offset="0" stopColor="#ff4a3d" />
          <stop offset="0.55" stopColor="#ff8a2a" />
          <stop offset="1" stopColor="#ffc81f" />
        </linearGradient>
        <linearGradient id={`${id}-r`} gradientUnits="userSpaceOnUse" x1="0" y1="13" x2="0" y2="36">
          <stop offset="0" stopColor="#ffc81f" />
          <stop offset="0.35" stopColor="#2dc35d" />
          <stop offset="1" stopColor="#3887ff" />
        </linearGradient>
      </defs>
      <rect width="48" height="48" rx={r} fill="#ffffff" />
      <g fill="none" strokeWidth={6.5} strokeLinecap="round" strokeLinejoin="round">
        <path d="M11.5 16.5L24 26l7-5.3" stroke="#ff4a3d" />
        <path d="M24 26l12.5-9.5" stroke={`url(#${id}-v)`} />
        <path d="M11.5 35V16.5" stroke={`url(#${id}-l)`} />
        <path d="M36.5 16.5V35" stroke={`url(#${id}-r)`} />
      </g>
    </svg>
  );
}
