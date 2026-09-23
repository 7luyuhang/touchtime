# ambi watch web

Design system and screens for ambi watch, built with Next.js (App Router, TypeScript, Tailwind CSS v4).

Base foundations and controls follow the Vercel DESIGN.md
([VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md/blob/main/design-md/vercel/DESIGN.md)).
The ambi watch layer (colour, type, spacing, radius, motion, watch-face sizes) comes from the Figma file
[Hardware - watch](https://www.figma.com/design/mRqDXY037g9l7zv89aZR8D/Hardware---watch).

## Run

```bash
npm install
npm run dev        # http://localhost:3000
npm run lint       # token drift check + eslint
npm run typecheck
npm run build
```

Routes: `/` overview, `/design-system` showcase, `/screens` and `/screens/[nodeId]` (one per Figma frame).

## Layers

| Layer | Path | Notes |
| --- | --- | --- |
| Tokens | `src/tokens/` | `vercel.ts` (DESIGN.md values), `ambi.ts` (watch layer), `themes.ts`, `motion.ts` |
| Generated CSS | `src/styles/tokens.css` | Built by `npm run tokens`; never edit by hand |
| Primitives | `src/components/primitives/` | Base controls from the DESIGN.md specs |
| Watch components | `src/components/watch/` | Watch-specific components composed from primitives |
| Screens | `src/screens/registry.ts` | Figma node id → route + screen component |
| Showcase | `src/app/design-system/` | Renders every token and control |

## Tokens

`src/tokens/*.ts` is the single source of truth. `npm run tokens` writes `src/styles/tokens.css`, which:

- defines Tailwind v4 `@theme` variables and clears Tailwind's default palette, type scale, radii, shadows and
  breakpoints, so only design-system values produce utilities (`bg-canvas`, `text-display-lg`, `rounded-pill`,
  `p-lg`, `h-control-md`, `tablet:`…);
- adds `elevation-0` … `elevation-5` utilities backed by `--elevation-level-*` so shadows can change per theme;
- exposes `--watch-face-*` and `--watch-motion-*` variables for the watch layer;
- overrides neutrals under `[data-theme="dark"]`.

`npm run lint` fails if the committed CSS is out of date with the TypeScript sources.

Spacing names (`xs`, `sm`, `md`…) share Tailwind's size keywords, so width utilities such as `max-w-md` resolve to
spacing values. Use the container tokens instead (`max-w-page`, `max-w-legacy`).

### Adding Figma values

Each ambi token in `src/tokens/ambi.ts` has a `status`. Placeholders borrow a Vercel value (`aliasOf`). When a Figma
variable is read, set `value`, `status: "figma"` and `figmaVariable`, then run `npm run tokens`. The showcase marks
every token with its status.

## Status

The Figma file was not readable when this was scaffolded, so the watch layer is placeholders only and the seven
screen routes render a blocked state. See `src/screens/registry.ts`.
