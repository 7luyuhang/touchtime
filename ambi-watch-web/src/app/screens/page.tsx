import type { Metadata } from "next";
import Link from "next/link";
import { Eyebrow, Heading, Text } from "@/components/primitives";
import { WatchFrame } from "@/components/watch";
import { screenGroups, screens } from "@/screens/registry";

export const metadata: Metadata = {
  title: "Screens",
};

export default function ScreensPage() {
  return (
    <main className="mx-auto flex max-w-page flex-col gap-2xl px-md pb-5xl pt-4xl tablet:px-lg">
      <header className="flex max-w-[760px] flex-col gap-md">
        <Eyebrow>Screens</Eyebrow>
        <Heading as="h1" size="xl">
          Every screen and state.
        </Heading>
        <Text size="lg">
          {screens.length} states from the reference images, each built at 410×502 inside the device mockup. Open one to
          compare it with its reference and try the interactive states.
        </Text>
      </header>
      {screenGroups.map((group) => (
        <section key={group} className="flex flex-col gap-lg border-t border-hairline pt-xl">
          <Heading as="h2" size="md">
            {group}.
          </Heading>
          <ul className="flex flex-wrap gap-xl">
            {screens
              .filter((screen) => screen.group === group)
              .map((screen) => (
                <li key={screen.slug}>
                  <Link href={`/screens/${screen.slug}`} className="group flex flex-col items-center gap-xs">
                    <div inert className="transition-transform duration-200 group-hover:-translate-y-1">
                      <WatchFrame scale={0.42}>
                        <screen.component />
                      </WatchFrame>
                    </div>
                    <Text as="span" size="sm" strong tone="ink">
                      {screen.title}
                    </Text>
                    {screen.interaction && (
                      <span className="font-mono text-caption-mono uppercase text-link">Interactive</span>
                    )}
                  </Link>
                </li>
              ))}
          </ul>
        </section>
      ))}
    </main>
  );
}
