import { DarkStage, DocGroup, DocSection, ScreenStage, SpecTable, StatusBadge } from "@/components/docs/docs";
import { Text } from "@/components/primitives/text";
import { GlassShape, HomeIndicator, StatusBar, WatchScreen } from "@/components/watch";
import {
  ambiColors,
  ambiGradients,
  ambiMotion,
  ambiRadii,
  ambiSizes,
  ambiTokenGroups,
  ambiTypography,
  watchScreen,
} from "@/tokens/ambi";

const specimens: Record<keyof typeof ambiTypography, string> = {
  "watch-time": "10:09",
  "watch-title": "Check email",
  "watch-title-strong": "Competitor Analysis",
  "watch-body": "Notes generated from",
  "watch-header": "Quick Actions",
};

export function WatchScreenSection() {
  return (
    <DocSection
      id="screen"
      layer="Foundations · ambi watch"
      title="Screen."
      description="Every screen is built at exactly 410×502 px, which is 205×251 pt at @2x (the Apple Watch Ultra canvas). All watch tokens are in these screen pixels."
    >
      <div className="flex flex-wrap items-start gap-2xl">
        <ScreenStage scale={0.8} caption="410 × 502 px · radius 100 · status 92 (46pt)">
          <WatchScreen background="ambient">
            <div className="absolute inset-x-0 top-0 h-(--watch-screen-status-bar) border-b border-dashed border-watch-mint bg-watch-mint/10" />
            <StatusBar />
            <div className="absolute inset-y-0 left-(--watch-screen-gutter) border-l border-dashed border-watch-white/30" />
            <div className="absolute inset-y-0 right-(--watch-screen-gutter) border-r border-dashed border-watch-white/30" />
            <p className="absolute inset-x-0 top-[230px] text-center font-mono text-[20px] text-watch-label-secondary">410 × 502</p>
            <HomeIndicator />
          </WatchScreen>
        </ScreenStage>
        <div className="min-w-[320px] flex-1">
          <TokenTable tokens={watchScreen} prefix="--watch-screen-" />
        </div>
      </div>
    </DocSection>
  );
}

export function WatchColorSection() {
  return (
    <DocSection
      id="watch-color"
      layer="Foundations · ambi watch"
      title="Color and gradients."
      description="Sampled from the reference pixels. Surfaces are near-black gradients that pick up one hue per context: green for ambient and capture, blue-green for the aurora capture, red for power."
    >
      <DocGroup title="Color">
        <DarkStage className="grid grid-cols-2 gap-md tablet:grid-cols-3 desktop:grid-cols-6">
          {Object.entries(ambiColors).map(([name, token]) => (
            <div key={name} className="flex flex-col gap-xs">
              <div className="h-14 rounded-md border border-watch-white/15" style={{ background: token.value }} />
              <span className="font-mono text-caption-mono text-watch-white">{name.replace("watch-", "")}</span>
              <span className="font-mono text-caption-mono text-watch-label-secondary">{token.value}</span>
            </div>
          ))}
        </DarkStage>
      </DocGroup>
      <DocGroup title="Gradients">
        <div className="grid grid-cols-2 gap-lg tablet:grid-cols-4 desktop:grid-cols-7">
          {Object.entries(ambiGradients).map(([name, token]) => (
            <div key={name} className="flex flex-col gap-xs">
              <div className="aspect-[410/502] rounded-[24%/20%]" style={{ background: token.value }} />
              <span className="font-mono text-caption-mono text-ink">{name}</span>
              <span className="text-caption text-mute">{token.note ?? `Source ${token.source}`}</span>
            </div>
          ))}
        </div>
      </DocGroup>
    </DocSection>
  );
}

export function WatchMaterialSection() {
  const circle = "M 51 1 A 50 50 0 1 1 51 101 A 50 50 0 1 1 51 1 Z";
  return (
    <DocSection
      id="materials"
      layer="Foundations · ambi watch"
      title="Materials."
      description="Glass is a translucent white fill over the scene plus a hairline that is brightest on top. Tinted rims (mint, red) mark the primary action of a screen."
    >
      <div className="grid gap-lg tablet:grid-cols-2 desktop:grid-cols-4">
        {[
          { label: "glass · round buttons, control bar", fill: "glass", stroke: "glass", bg: "capture" },
          { label: "glass-thin · list cards", fill: "thin", stroke: "glass", bg: "ambient" },
          { label: "glass-dark · listening bar", fill: "dark", stroke: "flat", bg: "ambient" },
          { label: "rim mint · camera", fill: "glass", stroke: "mint", bg: "capture" },
          { label: "rim red · power", fill: "glass", stroke: "red", bg: "power" },
        ].map((sample) => (
          <div key={sample.label} className="flex flex-col gap-xs">
            <div
              className="relative h-40 overflow-hidden rounded-lg"
              style={{ background: `var(--gradient-watch-${sample.bg})` }}
            >
              <GlassShape
                d={circle}
                width={102}
                height={102}
                fill={sample.fill as "glass"}
                stroke={sample.stroke as "glass"}
                className="left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2"
              />
            </div>
            <span className="font-mono text-caption-mono text-mute">{sample.label}</span>
          </div>
        ))}
      </div>
      <TokenTable tokens={ambiTokenGroups.Material.tokens} prefix="--watch-" />
    </DocSection>
  );
}

export function WatchTypeSection() {
  return (
    <DocSection
      id="watch-type"
      layer="Foundations · ambi watch"
      title="Typography."
      description="Two sizes carry almost everything: 32px (16pt) titles and 28px (14pt) body on a 40px line. The header is a flared serif. Font families are inferred; see the stack notes."
    >
      <DarkStage className="flex-col items-stretch gap-0 p-0">
        {Object.entries(ambiTypography).map(([name, style]) => (
          <div key={name} className="grid gap-xs border-b border-watch-white/10 p-lg desktop:grid-cols-[260px_1fr] desktop:items-baseline">
            <div className="flex flex-col">
              <span className="font-mono text-caption-mono text-watch-white">{name}</span>
              <span className="font-mono text-caption-mono text-watch-label-secondary">
                {style.fontSize}/{style.lineHeight} · {style.fontWeight} · {style.fontFamily}
              </span>
            </div>
            <p
              className={name === "watch-header" ? "text-watch-mint" : undefined}
              style={{
                fontFamily: `var(--font-${style.fontFamily})`,
                fontSize: `var(--text-${name})`,
                lineHeight: `var(--text-${name}--line-height)`,
                letterSpacing: `var(--text-${name}--letter-spacing)`,
                fontWeight: `var(--text-${name}--font-weight)`,
              }}
            >
              {specimens[name as keyof typeof specimens]}
            </p>
          </div>
        ))}
      </DarkStage>
      <TokenTable tokens={ambiTokenGroups["Font stack"].tokens} prefix="--font-" />
    </DocSection>
  );
}

export function WatchShapeSection() {
  return (
    <DocSection
      id="watch-shape"
      layer="Foundations · ambi watch"
      title="Radius, sizes and motion."
      description="Controls are circles and pills; cards use large radii that echo the 100px screen corner."
    >
      <DocGroup title="Radius">
        <DarkStage>
          {Object.entries(ambiRadii).map(([name, token]) => (
            <div key={name} className="flex flex-col items-center gap-xs">
              <div className="size-24 border border-watch-white/40 bg-watch-white/10" style={{ borderRadius: token.value }} />
              <span className="font-mono text-caption-mono text-watch-label-secondary">
                {name} · {token.value}
              </span>
            </div>
          ))}
        </DarkStage>
      </DocGroup>
      <DocGroup title="Sizes">
        <TokenTable tokens={ambiSizes} prefix="--spacing-watch-" />
      </DocGroup>
      <DocGroup title="Motion">
        <TokenTable tokens={ambiMotion} prefix="--watch-motion-" />
        <Text size="sm">The stills contain no motion. These values drive the interactive states until motion specs exist.</Text>
      </DocGroup>
    </DocSection>
  );
}

function TokenTable({ tokens, prefix }: { tokens: Record<string, { value: string; status: "sampled" | "assumed"; source: string; note?: string }>; prefix: string }) {
  return (
    <SpecTable
      head={["Token", "Value", "Status", "Source", "Note"]}
      rows={Object.entries(tokens).map(([name, token]) => [
        <span key="n" className="font-mono text-caption-mono text-ink">{`${prefix}${name}`}</span>,
        <span key="v" className="block max-w-[280px] truncate font-mono text-caption-mono" title={token.value}>
          {token.value}
        </span>,
        <StatusBadge key="s" status={token.status} />,
        token.source,
        token.note ?? "—",
      ])}
    />
  );
}
