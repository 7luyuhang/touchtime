import type { Metadata } from "next";
import { Eyebrow, Heading, Text } from "@/components/primitives";
import { PrimitivesSection } from "../_sections/primitives";

export const metadata: Metadata = {
  title: "Base controls",
};

export default function ControlsPage() {
  return (
    <>
      <header className="flex max-w-[760px] flex-col gap-md pb-2xl">
        <Eyebrow>Design system · Base controls</Eyebrow>
        <Heading as="h1" size="xl">
          Base controls.
        </Heading>
        <Text size="lg">
          Built to the Vercel DESIGN.md component specs. They power this site and any companion surfaces; the watch
          components are a separate layer.
        </Text>
      </header>
      <PrimitivesSection />
    </>
  );
}
