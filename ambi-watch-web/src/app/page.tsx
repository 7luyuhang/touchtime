import Link from "next/link";
import { buttonStyles, Card, Eyebrow, Heading, Icon, Text } from "@/components/primitives";
import { screens } from "@/screens/registry";

export default function Home() {
  const implemented = screens.filter((screen) => screen.status === "implemented").length;

  return (
    <main className="mx-auto flex max-w-page flex-col gap-3xl px-md py-5xl tablet:px-lg">
      <section className="flex max-w-[760px] flex-col gap-md">
        <Eyebrow>ambi watch · web</Eyebrow>
        <Heading as="h1" size="xl">
          Design system and screens for ambi watch.
        </Heading>
        <Text size="lg">
          Tokens, base controls and watch components built on the Vercel DESIGN.md, with the ambi watch layer extracted
          from Figma.
        </Text>
        <div className="flex flex-wrap gap-sm pt-xs">
          <Link href="/design-system" className={buttonStyles({ size: "lg" })}>
            Open design system <Icon name="arrow-right" />
          </Link>
          <Link href="/screens" className={buttonStyles({ size: "lg", variant: "secondary" })}>
            View screens
          </Link>
        </div>
      </section>
      <section className="grid gap-lg tablet:grid-cols-3">
        <Card>
          <Eyebrow>Tokens</Eyebrow>
          <Heading as="h2" size="sm" className="mt-xs">
            Vercel base + ambi layer.
          </Heading>
          <Text size="sm" className="mt-xs">
            Generated to CSS variables and Tailwind utilities from typed sources in <code>src/tokens</code>.
          </Text>
        </Card>
        <Card>
          <Eyebrow>Primitives</Eyebrow>
          <Heading as="h2" size="sm" className="mt-xs">
            Base controls.
          </Heading>
          <Text size="sm" className="mt-xs">
            Button, IconButton, Tabs, Input, Badge, Banner, Card, Text, Link and Code.
          </Text>
        </Card>
        <Card>
          <Eyebrow>Screens</Eyebrow>
          <Heading as="h2" size="sm" className="mt-xs">
            {implemented} of {screens.length} implemented.
          </Heading>
          <Text size="sm" className="mt-xs">
            Each Figma frame has a route. Frames stay blocked until the Figma file is readable.
          </Text>
        </Card>
      </section>
    </main>
  );
}
