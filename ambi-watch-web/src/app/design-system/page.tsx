import type { Metadata } from "next";
import { Badge, Eyebrow, Heading, Text } from "@/components/primitives";
import {
  ColorSection,
  ElevationMotionSection,
  SpacingRadiusSection,
  TypographySection,
} from "./_sections/foundations";
import { PrimitivesSection } from "./_sections/primitives";
import { WatchLayerSection } from "./_sections/watch-layer";

export const metadata: Metadata = {
  title: "Design system",
};

const toc = [
  { id: "color", label: "Color" },
  { id: "typography", label: "Typography" },
  { id: "spacing", label: "Spacing & radius" },
  { id: "elevation", label: "Elevation & motion" },
  { id: "primitives", label: "Base controls" },
  { id: "watch", label: "ambi watch layer" },
];

export default function DesignSystemPage() {
  return (
    <main className="mx-auto max-w-page px-md pb-5xl pt-4xl tablet:px-lg">
      <header className="flex max-w-[760px] flex-col gap-md pb-2xl">
        <Eyebrow>Design system</Eyebrow>
        <Heading as="h1" size="xl">
          ambi watch design system.
        </Heading>
        <Text size="lg">
          Vercel DESIGN.md foundations and base controls, with an ambi watch layer on top. Watch tokens are placeholders
          until the Figma file is readable.
        </Text>
        <div className="flex flex-wrap gap-xs">
          <Badge mono>BASE · VERCEL DESIGN.MD</Badge>
          <Badge variant="warning" mono>
            FIGMA LAYER · PENDING
          </Badge>
        </div>
      </header>
      <nav aria-label="Sections" className="flex flex-wrap gap-xs pb-2xl">
        {toc.map((item) => (
          <a
            key={item.id}
            href={`#${item.id}`}
            className="rounded-pill-sm bg-canvas px-md py-xs text-body-sm text-body elevation-1 transition-colors hover:text-ink"
          >
            {item.label}
          </a>
        ))}
      </nav>
      <ColorSection />
      <TypographySection />
      <SpacingRadiusSection />
      <ElevationMotionSection />
      <PrimitivesSection />
      <WatchLayerSection />
    </main>
  );
}
