import type { Metadata } from "next";
import Link from "next/link";
import { notFound } from "next/navigation";
import { Badge, buttonStyles, Card, Eyebrow, Heading, Icon, Text } from "@/components/primitives";
import { WatchFrame } from "@/components/watch";
import { getScreen, screenLabel, screens } from "@/screens/registry";

export const dynamicParams = false;

export function generateStaticParams() {
  return screens.map((screen) => ({ nodeId: screen.nodeId }));
}

export async function generateMetadata({ params }: PageProps<"/screens/[nodeId]">): Promise<Metadata> {
  const { nodeId } = await params;
  const screen = getScreen(nodeId);
  if (!screen) return {};
  return { title: screenLabel(screen, screens.indexOf(screen)) };
}

export default async function ScreenPage({ params }: PageProps<"/screens/[nodeId]">) {
  const { nodeId } = await params;
  const screen = getScreen(nodeId);
  if (!screen) notFound();

  const index = screens.indexOf(screen);

  return (
    <main className="mx-auto flex max-w-page flex-col gap-2xl px-md pb-5xl pt-4xl tablet:px-lg">
      <header className="flex flex-col gap-md">
        <Link href="/screens" className="self-start text-body-sm text-body hover:text-ink">
          ← All screens
        </Link>
        <Eyebrow>Screen {index + 1} · node-id {screen.nodeId}</Eyebrow>
        <div className="flex flex-wrap items-center gap-sm">
          <Heading as="h1" size="lg">
            {screenLabel(screen, index)}
          </Heading>
          <Badge variant={screen.status === "implemented" ? "cyan" : "warning"} mono>
            {screen.status.toUpperCase()}
          </Badge>
        </div>
        <a
          href={screen.figmaUrl}
          target="_blank"
          rel="noreferrer"
          className={`${buttonStyles({ variant: "secondary", size: "sm", shape: "rounded" })} self-start`}
        >
          Open frame in Figma <Icon name="arrow-up-right" size={12} />
        </a>
      </header>

      {screen.status === "implemented" ? (
        <WatchFrame caption={`node ${screen.nodeId}`}>
          <screen.component />
        </WatchFrame>
      ) : (
        <Card variant="soft" className="flex max-w-[640px] flex-col gap-sm border border-dashed border-hairline-strong">
          <Heading as="h2" size="sm">
            Blocked on Figma access.
          </Heading>
          <Text size="sm">{screen.blockedReason}</Text>
          <Text size="sm">
            This route is reserved for the frame. Its layout, copy and watch-specific components will be built from the
            Figma node once it can be read, rather than guessed.
          </Text>
        </Card>
      )}
    </main>
  );
}
