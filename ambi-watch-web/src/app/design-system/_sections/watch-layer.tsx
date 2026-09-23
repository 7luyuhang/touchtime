import Link from "next/link";
import { DocGroup, DocSection, SpecTable, StatusBadge } from "@/components/docs/docs";
import { Badge, Banner, buttonStyles, Icon, Text } from "@/components/primitives";
import { WatchFrame } from "@/components/watch";
import { screenLabel, screens } from "@/screens/registry";
import { ambiColors, ambiMotion, watchFace } from "@/tokens/ambi";
import type { AmbiToken } from "@/tokens/types";

const cssVarGroups: Array<{ group: string; prefix: string; tokens: Record<string, AmbiToken> }> = [
  { group: "Color", prefix: "--color-", tokens: ambiColors },
  { group: "Watch face", prefix: "--watch-face-", tokens: watchFace },
  { group: "Motion", prefix: "--watch-motion-", tokens: ambiMotion },
];

export function WatchLayerSection() {
  return (
    <DocSection
      id="watch"
      layer="Tokens + components · ambi watch layer"
      title="ambi watch layer."
      description="Tokens and components specific to the watch, extracted from Figma file “Hardware - watch”. The file was not readable when this was built, so every value below is a placeholder that borrows a Vercel base value."
    >
      <Banner className="self-start">
        <Badge variant="warning" mono>
          BLOCKED
        </Badge>
        Waiting on Figma access to replace placeholders
      </Banner>

      <DocGroup title="Tokens">
        <SpecTable
          head={["CSS variable", "Value", "Status", "Borrowed from", "Note"]}
          rows={cssVarGroups.flatMap(({ prefix, tokens }) =>
            Object.entries(tokens).map(([name, token]) => [
              <span key="n" className="font-mono text-caption-mono text-ink">{`${prefix}${name}`}</span>,
              <span key="v" className="inline-flex items-center gap-xs font-mono text-caption-mono">
                {token.value.startsWith("#") && (
                  <span className="size-3 rounded-full elevation-1" style={{ background: token.value }} />
                )}
                {token.value}
              </span>,
              <StatusBadge key="s" status={token.status} />,
              token.aliasOf ?? "—",
              token.note ?? "—",
            ]),
          )}
        />
      </DocGroup>

      <DocGroup title="WatchFrame">
        <div className="flex flex-wrap items-start gap-2xl">
          <WatchFrame caption="WatchFrame · placeholder face size">
            <div className="flex h-full items-center justify-center">
              <span className="font-mono text-caption-mono opacity-60">PLACEHOLDER</span>
            </div>
          </WatchFrame>
          <Text size="sm" className="max-w-[420px]">
            Renders a screen at 1:1 watch-face size from the <code className="font-mono">--watch-face-*</code>{" "}
            tokens. Once the Figma frames are readable, the frame width, height and corner radius come straight
            from them and each screen composes its content inside this frame.
          </Text>
        </div>
      </DocGroup>

      <DocGroup title="Screens (Figma frames)">
        <div className="grid gap-md tablet:grid-cols-2 desktop:grid-cols-4">
          {screens.map((screen, index) => (
            <div key={screen.nodeId} className="flex flex-col gap-sm rounded-md bg-canvas p-md elevation-2">
              <div className="flex items-center justify-between gap-xs">
                <Text size="sm" strong tone="ink">
                  {screenLabel(screen, index)}
                </Text>
                <Badge variant={screen.status === "implemented" ? "cyan" : "warning"} mono>
                  {screen.status.toUpperCase()}
                </Badge>
              </div>
              <span className="font-mono text-caption-mono text-mute">node {screen.nodeId}</span>
              <div className="flex gap-xs">
                <Link href={`/screens/${screen.nodeId}`} className={buttonStyles({ variant: "secondary", size: "xs", shape: "rounded" })}>
                  Route
                </Link>
                <a
                  href={screen.figmaUrl}
                  target="_blank"
                  rel="noreferrer"
                  className={buttonStyles({ variant: "ghost", size: "xs", shape: "rounded" })}
                >
                  Figma <Icon name="arrow-up-right" size={12} />
                </a>
              </div>
            </div>
          ))}
        </div>
      </DocGroup>
    </DocSection>
  );
}
