import type { Metadata } from "next";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Badge, buttonStyles, Eyebrow, Heading, Icon, Text } from "@/components/primitives";
import { WatchFrame, WatchScreen } from "@/components/watch";
import { getScreen, screens } from "@/screens/registry";

export const dynamicParams = false;

export function generateStaticParams() {
  return screens.map((screen) => ({ slug: screen.slug }));
}

export async function generateMetadata({ params }: PageProps<"/screens/[slug]">): Promise<Metadata> {
  const { slug } = await params;
  return { title: getScreen(slug)?.title };
}

export default async function ScreenPage({ params }: PageProps<"/screens/[slug]">) {
  const { slug } = await params;
  const screen = getScreen(slug);
  if (!screen) notFound();

  const index = screens.indexOf(screen);
  const prev = screens[index - 1];
  const next = screens[index + 1];
  const siblings = screens.filter((item) => item.group === screen.group);

  return (
    <main className="mx-auto flex max-w-page flex-col gap-xl px-md pb-5xl pt-3xl tablet:px-lg">
      <header className="flex flex-col gap-sm">
        <Link href="/screens" className="self-start text-body-sm text-body hover:text-ink">
          ← All screens
        </Link>
        <Eyebrow>
          {screen.group} · {index + 1} of {screens.length}
        </Eyebrow>
        <div className="flex flex-wrap items-center gap-sm">
          <Heading as="h1" size="lg">
            {screen.title}
          </Heading>
          {screen.interaction && (
            <Badge variant="info" mono>
              INTERACTIVE
            </Badge>
          )}
        </div>
        <Text size="sm" className="font-mono">
          Reference: {screen.source}
        </Text>
      </header>

      {siblings.length > 1 && (
        <nav aria-label={`${screen.group} states`} className="flex flex-wrap gap-xs">
          {siblings.map((item) => (
            <Link
              key={item.slug}
              href={`/screens/${item.slug}`}
              aria-current={item.slug === screen.slug ? "page" : undefined}
              className={buttonStyles({
                variant: item.slug === screen.slug ? "primary" : "secondary",
                size: "sm",
                shape: "rounded",
              })}
            >
              {item.title.replace(`${screen.group} · `, "")}
            </Link>
          ))}
        </nav>
      )}

      <div data-compare className="flex flex-wrap items-start gap-2xl rounded-lg bg-canvas p-xl elevation-1">
        <div className="flex flex-col items-center gap-sm">
          <Badge variant="inverted" mono>
            BUILD · 410×502
          </Badge>
          <WatchFrame priority>
            <screen.component />
          </WatchFrame>
        </div>
        <div className="flex flex-col items-center gap-sm">
          <Badge mono>REFERENCE</Badge>
          <WatchFrame priority>
            <WatchScreen label="Reference image">
              <Image src={screen.reference} alt={`Reference: ${screen.title}`} width={410} height={502} unoptimized priority />
            </WatchScreen>
          </WatchFrame>
        </div>
        <aside className="flex max-w-[300px] flex-col gap-md pt-2xl">
          {screen.interaction && (
            <div className="flex flex-col gap-xs">
              <Text size="sm" strong tone="ink">
                Try it
              </Text>
              <Text size="sm">{screen.interaction}</Text>
            </div>
          )}
          {screen.notes && (
            <div className="flex flex-col gap-xs">
              <Text size="sm" strong tone="ink">
                Notes
              </Text>
              <Text size="sm">{screen.notes}</Text>
            </div>
          )}
        </aside>
      </div>

      <nav aria-label="Screens" className="flex justify-between gap-md">
        {prev ? (
          <Link href={`/screens/${prev.slug}`} className={buttonStyles({ variant: "secondary", size: "md", shape: "rounded" })}>
            ← {prev.title}
          </Link>
        ) : (
          <span />
        )}
        {next && (
          <Link href={`/screens/${next.slug}`} className={buttonStyles({ variant: "secondary", size: "md", shape: "rounded" })}>
            {next.title} <Icon name="arrow-right" />
          </Link>
        )}
      </nav>
    </main>
  );
}
