import type { Metadata } from "next";
import { Badge, Eyebrow, Heading, Text } from "@/components/primitives";
import {
  ColorSection,
  ElevationMotionSection,
  SpacingRadiusSection,
  TypographySection,
} from "./_sections/foundations";
import {
  WatchColorSection,
  WatchMaterialSection,
  WatchScreenSection,
  WatchShapeSection,
  WatchTypeSection,
} from "./_sections/watch-foundations";

export const metadata: Metadata = {
  title: "Foundations",
};

export default function FoundationsPage() {
  return (
    <>
      <header className="flex max-w-[760px] flex-col gap-md pb-2xl">
        <Eyebrow>Design system · Foundations</Eyebrow>
        <Heading as="h1" size="xl">
          ambi watch foundations.
        </Heading>
        <Text size="lg">
          Watch tokens sampled from the reference images, layered on the Vercel DESIGN.md foundations that drive the
          base controls and this site.
        </Text>
        <div className="flex flex-wrap gap-xs">
          <Badge variant="cyan" mono>
            SAMPLED · FROM PIXELS
          </Badge>
          <Badge variant="warning" mono>
            ASSUMED · INFERRED
          </Badge>
          <Badge mono>VERCEL · DESIGN.MD</Badge>
        </div>
      </header>
      <WatchScreenSection />
      <WatchColorSection />
      <WatchMaterialSection />
      <WatchTypeSection />
      <WatchShapeSection />
      <ColorSection />
      <TypographySection />
      <SpacingRadiusSection />
      <ElevationMotionSection />
    </>
  );
}
