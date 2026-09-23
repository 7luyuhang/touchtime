import Link from "next/link";
import { buttonStyles, Card, Eyebrow, Heading, Icon, Text } from "@/components/primitives";
import { WatchFrame } from "@/components/watch";
import { getScreen, screens } from "@/screens/registry";

const featured = ["watch-face", "quick-actions", "capture-now-playing", "power-off-3", "recaps"];

const sections = [
  {
    href: "/design-system",
    eyebrow: "Foundations",
    title: "Color, type, materials.",
    body: "Screen, color, gradients, glass, type scale, radius, sizes and motion sampled from the references, plus the Vercel base.",
  },
  {
    href: "/design-system/controls",
    eyebrow: "Base controls",
    title: "Vercel DESIGN.md.",
    body: "Button, IconButton, Tabs, Input, Badge, Banner, Card, Text, Link and Code.",
  },
  {
    href: "/design-system/watch",
    eyebrow: "Watch components",
    title: "Built for 410×502.",
    body: "Round buttons, control bars, list cards, sheets, pills, indicators, power slider, clock and waveform.",
  },
];

export default function Home() {
  return (
    <main className="mx-auto flex max-w-page flex-col gap-3xl px-md py-4xl tablet:px-lg">
      <section className="flex max-w-[760px] flex-col gap-md">
        <Eyebrow>ambi watch · design system</Eyebrow>
        <Heading as="h1" size="xl">
          The ambi watch interface, as a system.
        </Heading>
        <Text size="lg">
          Foundations, base controls and watch components, with all {screens.length} screens and states rebuilt at
          410×502 inside the device.
        </Text>
        <div className="flex flex-wrap gap-sm pt-xs">
          <Link href="/design-system" className={buttonStyles({ size: "lg" })}>
            Browse the design system <Icon name="arrow-right" />
          </Link>
          <Link href="/screens" className={buttonStyles({ size: "lg", variant: "secondary" })}>
            View screens
          </Link>
        </div>
      </section>

      <section aria-label="Featured screens" className="flex flex-wrap gap-lg">
        {featured.map((slug) => {
          const screen = getScreen(slug);
          if (!screen) return null;
          return (
            <Link key={slug} href={`/screens/${slug}`}>
              <div inert>
                <WatchFrame scale={0.4} caption={screen.title}>
                  <screen.component />
                </WatchFrame>
              </div>
            </Link>
          );
        })}
      </section>

      <section className="grid gap-lg tablet:grid-cols-3">
        {sections.map((section) => (
          <Link key={section.href} href={section.href} className="rounded-md transition-shadow hover:elevation-4">
            <Card className="h-full">
              <Eyebrow>{section.eyebrow}</Eyebrow>
              <Heading as="h2" size="sm" className="mt-xs">
                {section.title}
              </Heading>
              <Text size="sm" className="mt-xs">
                {section.body}
              </Text>
            </Card>
          </Link>
        ))}
      </section>
    </main>
  );
}
