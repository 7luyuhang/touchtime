/**
 * The DESIGN.md has no motion section. These base values match the 150ms ease
 * used across Geist controls and only drive hover/focus transitions; the
 * watch-specific motion tokens live in `ambi.ts`.
 */
export const duration = {
  fast: "150ms",
  base: "200ms",
  slow: "300ms",
} as const;

export const easing = {
  standard: "cubic-bezier(0.4, 0, 0.2, 1)",
  out: "cubic-bezier(0, 0, 0.2, 1)",
  in: "cubic-bezier(0.4, 0, 1, 1)",
} as const;
