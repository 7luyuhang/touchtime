# ambi watch web

Design system and screens for ambi watch, built with Next.js (App Router, TypeScript, Tailwind CSS v4).

- **Watch layer**: tokens, components and 15 screens/states rebuilt from the reference images at the canonical
  **410×502 px** screen (205×251 pt at @2x).
- **Base controls**: foundations and controls from the Vercel DESIGN.md
  ([VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md/blob/main/design-md/vercel/DESIGN.md)).

## Run

```bash
npm install
npm run dev        # http://localhost:3000
npm run lint       # token drift check + eslint
npm run typecheck
npm run build && npm run start
```

| Route | Content |
| --- | --- |
| `/` | Overview |
| `/design-system` | Foundations: screen, colour, gradients, materials, type, radius, sizes, motion, Vercel base |
| `/design-system/controls` | Base controls (Vercel DESIGN.md) |
| `/design-system/watch` | Watch components |
| `/screens`, `/screens/[slug]` | Every screen in the device mockup, next to its reference crop |

## Layers

| Layer | Path | Notes |
| --- | --- | --- |
| Tokens | `src/tokens/` | `ambi.ts` (watch layer, sampled), `vercel.ts` (DESIGN.md), `themes.ts`, `motion.ts` |
| Generated CSS | `src/styles/tokens.css` | Built by `npm run tokens`; never edit by hand |
| Material recipes | `src/styles/watch.css` | Glass fills, gradient hairlines, press feedback |
| Primitives | `src/components/primitives/` | Base controls from the DESIGN.md specs |
| Watch components | `src/components/watch/` | Frame, buttons, control bars, cards, sheets, indicators, power, clock, waveform |
| Screens | `src/screens/` | Screen compositions and `registry.tsx` (slug → component, reference, notes) |
| Reference assets | `public/watch`, `public/references`, `public/samples` | Device frame, 410×502 reference crops, sample imagery |

## Tokens

`src/tokens/*.ts` is the single source of truth. `npm run tokens` writes `src/styles/tokens.css`, which defines Tailwind
v4 `@theme` variables and clears Tailwind's default palette, type scale, radii, shadows and breakpoints, so only
design-system values produce utilities (`bg-watch-black`, `text-watch-title`, `rounded-watch-card`,
`size-watch-button-lg`, `watch-gradient-ambient`, `bg-canvas`, `text-display-lg`…). `npm run lint` fails if the
committed CSS is out of date.

Every ambi token carries a `status` (`sampled` from pixels or `assumed`) and the source image, and the foundations page
shows both.

Spacing names (`xs`, `sm`, `md`…) share Tailwind's size keywords, so width utilities such as `max-w-md` resolve to
spacing values. Use the container tokens instead (`max-w-page`, `max-w-legacy`).

## Watch screens

Screens position elements in screen pixels inside `WatchScreen` (410×502). `WatchFrame` overlays the device mockup,
whose screen cutout is transparent, so content is clipped by the real bezel shape and stays interactive.
