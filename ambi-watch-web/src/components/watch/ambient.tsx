import { useId } from "react";
import { cx } from "@/lib/cx";

const CAPTURE_BRIGHT = "M-10 285C60 293 120 285 180 262S260 240 320 240S390 241 420 239";
const CAPTURE_FAINT = "M-10 160C90 162 170 200 250 222S350 208 420 210";

/** Two crossing light threads, brightest toward the screen edges (03). */
export function CaptureWaves({ className }: { className?: string }) {
  const id = useId();
  return (
    <svg className={cx("pointer-events-none absolute inset-0", className)} width={410} height={502} aria-hidden>
      <defs>
        <filter id={`${id}-glow`} x="-10%" y="-50%" width="120%" height="200%">
          <feGaussianBlur stdDeviation="3" />
        </filter>
        <linearGradient id={`${id}-edge`} gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="410" y2="0">
          <stop offset="0" stopColor="#fff" stopOpacity={0.6} />
          <stop offset="0.5" stopColor="#fff" stopOpacity={0.14} />
          <stop offset="1" stopColor="#fff" stopOpacity={0.55} />
        </linearGradient>
      </defs>
      <g fill="none" strokeLinecap="round">
        <path d={CAPTURE_FAINT} stroke="rgba(255,255,255,0.1)" strokeWidth={6} filter={`url(#${id}-glow)`} />
        <path d={CAPTURE_FAINT} stroke="rgba(255,255,255,0.14)" strokeWidth={1.5} />
        <path d={CAPTURE_BRIGHT} stroke={`url(#${id}-edge)`} strokeWidth={8} opacity={0.5} filter={`url(#${id}-glow)`} />
        <path d={CAPTURE_BRIGHT} stroke={`url(#${id}-edge)`} strokeWidth={2} />
      </g>
    </svg>
  );
}

/** Single light thread plus film grain over the green→blue gradient (04). */
export function AuroraWave({ className }: { className?: string }) {
  const id = useId();
  return (
    <svg className={cx("pointer-events-none absolute inset-0", className)} width={410} height={502} aria-hidden>
      <defs>
        <filter id={`${id}-glow`} x="-10%" y="-50%" width="120%" height="200%">
          <feGaussianBlur stdDeviation="3" />
        </filter>
        <filter id={`${id}-grain`}>
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" stitchTiles="stitch" />
          <feColorMatrix type="saturate" values="0" />
        </filter>
      </defs>
      <rect width="410" height="502" filter={`url(#${id}-grain)`} opacity={0.12} />
      <g fill="none" strokeLinecap="round">
        <path d="M-10 288C60 292 150 262 230 262S340 230 420 220" stroke="rgba(190,210,255,0.18)" strokeWidth={8} filter={`url(#${id}-glow)`} />
        <path d="M-10 288C60 292 150 262 230 262S340 230 420 220" stroke="rgba(220,230,255,0.32)" strokeWidth={2} />
      </g>
    </svg>
  );
}

/** Layered hills behind “Listening…” (06). */
export function ListeningHills({ className }: { className?: string }) {
  return (
    <svg className={cx("pointer-events-none absolute inset-0", className)} width={410} height={502} aria-hidden>
      <path d="M0 262C70 238 170 232 250 226S360 206 410 214V502H0Z" fill="rgba(42,82,68,0.35)" />
      <path d="M0 250C60 252 130 286 205 332C260 338 330 332 370 312S400 282 410 274V502H0Z" fill="rgba(38,78,64,0.55)" />
      <path d="M0 250C60 252 130 286 205 332" fill="none" stroke="rgba(120,180,155,0.18)" strokeWidth={1.5} />
    </svg>
  );
}
