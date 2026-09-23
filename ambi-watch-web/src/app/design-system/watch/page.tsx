import type { Metadata } from "next";
import { Eyebrow, Heading, Text } from "@/components/primitives";
import { WatchComponentsSection } from "../_sections/watch-components";

export const metadata: Metadata = {
  title: "Watch components",
};

export default function WatchComponentsPage() {
  return (
    <>
      <header className="flex max-w-[760px] flex-col gap-md pb-2xl">
        <Eyebrow>Design system · Watch components</Eyebrow>
        <Heading as="h1" size="xl">
          Watch components.
        </Heading>
        <Text size="lg">
          The pieces every screen is composed from, drawn at the 410×502 screen scale from the sampled watch tokens.
        </Text>
      </header>
      <WatchComponentsSection />
    </>
  );
}
