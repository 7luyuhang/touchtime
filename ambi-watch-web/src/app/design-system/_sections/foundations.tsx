import { DocGroup, DocSection, SpecTable, StatusBadge, Swatch } from "@/components/docs/docs";
import { Text } from "@/components/primitives/text";
import { duration, easing } from "@/tokens/motion";
import { darkColorOverrides } from "@/tokens/themes";
import {
  colorGroups,
  colors,
  controlHeights,
  elevation,
  radius,
  spacing,
  typography,
  type ColorName,
  type ElevationName,
} from "@/tokens/vercel";

const gradientPairs = [
  { name: "Develop", start: "gradient-develop-start", end: "gradient-develop-end" },
  { name: "Preview", start: "gradient-preview-start", end: "gradient-preview-end" },
  { name: "Ship", start: "gradient-ship-start", end: "gradient-ship-end" },
] as const;

const specimen = "Sphinx of black quartz, judge my vow.";

export function ColorSection() {
  const dark = darkColorOverrides as Partial<Record<ColorName, string>>;
  return (
    <DocSection
      id="color"
      layer="Tokens · Vercel base"
      title="Color."
      description="Every value is transcribed from the Vercel DESIGN.md. Neutrals flip on the dark surface; those dark values are provisional until the Figma watch palette is available."
    >
      {Object.entries(colorGroups).map(([group, names]) => (
        <DocGroup key={group} title={group}>
          <div className="grid grid-cols-2 gap-md tablet:grid-cols-4 desktop:grid-cols-6">
            {names.map((name) => (
              <Swatch key={name} name={name} light={colors[name]} dark={dark[name]} />
            ))}
          </div>
        </DocGroup>
      ))}
      <DocGroup title="Brand gradient pairs (hero scale only)">
        <div className="grid gap-md tablet:grid-cols-3">
          {gradientPairs.map((pair) => (
            <div key={pair.name} className="flex flex-col gap-xs">
              <div
                className="h-16 rounded-md"
                style={{ background: `linear-gradient(90deg, var(--color-${pair.start}), var(--color-${pair.end}))` }}
              />
              <span className="font-mono text-caption-mono text-mute">{pair.name}</span>
            </div>
          ))}
        </div>
      </DocGroup>
      <div className="flex items-center gap-xs">
        <StatusBadge status="provisional" />
        <Text size="sm">Dark-surface neutrals shown after the slash in each swatch.</Text>
      </div>
    </DocSection>
  );
}

export function TypographySection() {
  return (
    <DocSection
      id="typography"
      layer="Tokens · Vercel base"
      title="Typography."
      description="Geist for everything narrative, Geist Mono for technical labels. Weight 600 is the ceiling; display sizes track negative."
    >
      <div className="flex flex-col divide-y divide-hairline rounded-md bg-canvas elevation-1">
        {Object.entries(typography).map(([name, style]) => (
          <div key={name} className="grid gap-xs p-md desktop:grid-cols-[220px_1fr] desktop:items-baseline">
            <div className="flex flex-col">
              <span className="font-mono text-caption-mono text-ink">{name}</span>
              <span className="font-mono text-caption-mono text-mute">
                {style.fontSize}/{style.lineHeight} · {style.fontWeight} · {style.letterSpacing}px
              </span>
            </div>
            <p
              className="truncate text-ink"
              style={{
                fontFamily: `var(--font-${style.fontFamily})`,
                fontSize: `var(--text-${name})`,
                lineHeight: `var(--text-${name}--line-height)`,
                letterSpacing: `var(--text-${name}--letter-spacing)`,
                fontWeight: `var(--text-${name}--font-weight)`,
              }}
            >
              {specimen}
            </p>
          </div>
        ))}
      </div>
    </DocSection>
  );
}

export function SpacingRadiusSection() {
  return (
    <DocSection
      id="spacing"
      layer="Tokens · Vercel base"
      title="Spacing, radius and control heights."
      description="4px base unit. Pill (100px) is the marketing CTA shape; 6px is the in-app control radius."
    >
      <DocGroup title="Spacing">
        <div className="flex flex-col gap-xs">
          {Object.entries(spacing).map(([name, value]) => (
            <div key={name} className="grid grid-cols-[96px_1fr] items-center gap-md">
              <span className="font-mono text-caption-mono text-mute">
                {name} · {value}
              </span>
              <div className="h-xs rounded-xs bg-link" style={{ width: value }} />
            </div>
          ))}
        </div>
      </DocGroup>
      <DocGroup title="Radius">
        <div className="flex flex-wrap gap-lg">
          {Object.entries(radius).map(([name, value]) => (
            <div key={name} className="flex flex-col items-center gap-xs">
              <div className="size-16 bg-canvas elevation-2" style={{ borderRadius: `var(--radius-${name})` }} />
              <span className="font-mono text-caption-mono text-mute">
                {name} · {value}
              </span>
            </div>
          ))}
        </div>
      </DocGroup>
      <DocGroup title="Control heights">
        <div className="flex flex-wrap items-end gap-lg">
          {Object.entries(controlHeights).map(([name, value]) => (
            <div key={name} className="flex flex-col items-center gap-xs">
              <div className="w-16 rounded-sm bg-canvas elevation-1" style={{ height: value }} />
              <span className="font-mono text-caption-mono text-mute">
                control-{name} · {value}
              </span>
            </div>
          ))}
        </div>
      </DocGroup>
    </DocSection>
  );
}

export function ElevationMotionSection() {
  return (
    <DocSection
      id="elevation"
      layer="Tokens · Vercel base"
      title="Elevation and motion."
      description="Stacked small shadows plus an inset hairline ring, never one heavy drop. Motion is not specified by the DESIGN.md; base values below only drive control transitions."
    >
      <DocGroup title="Elevation">
        <div className="grid grid-cols-2 gap-lg tablet:grid-cols-3 desktop:grid-cols-6">
          {(Object.keys(elevation) as ElevationName[]).map((name) => (
            <div
              key={name}
              className="flex h-24 items-end rounded-md bg-canvas p-sm"
              style={{ boxShadow: `var(--elevation-${name})` }}
            >
              <span className="font-mono text-caption-mono text-mute">{name}</span>
            </div>
          ))}
        </div>
      </DocGroup>
      <DocGroup title="Base motion">
        <SpecTable
          head={["Token", "Value", "Status"]}
          rows={[
            ...Object.entries(duration).map(([name, value]) => [
              <span key="n" className="font-mono text-caption-mono text-ink">{`--duration-${name}`}</span>,
              value,
              <StatusBadge key="s" status="provisional" />,
            ]),
            ...Object.entries(easing).map(([name, value]) => [
              <span key="n" className="font-mono text-caption-mono text-ink">{`--ease-${name}`}</span>,
              value,
              <StatusBadge key="s" status="provisional" />,
            ]),
          ]}
        />
      </DocGroup>
    </DocSection>
  );
}
