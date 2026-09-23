import type { Metadata } from "next";
import Link from "next/link";
import { Badge, Eyebrow, Heading, Text } from "@/components/primitives";
import { screenLabel, screens } from "@/screens/registry";

export const metadata: Metadata = {
  title: "Screens",
};

export default function ScreensPage() {
  return (
    <main className="mx-auto flex max-w-page flex-col gap-2xl px-md pb-5xl pt-4xl tablet:px-lg">
      <header className="flex max-w-[760px] flex-col gap-md">
        <Eyebrow>Screens</Eyebrow>
        <Heading as="h1" size="lg">
          Figma frames.
        </Heading>
        <Text>
          One route per frame in “Hardware - watch”. Blocked frames are waiting on Figma access; nothing is drawn for
          them until the real frame can be read.
        </Text>
      </header>
      <ol className="grid gap-md tablet:grid-cols-2 desktop:grid-cols-3">
        {screens.map((screen, index) => (
          <li key={screen.nodeId}>
            <Link
              href={`/screens/${screen.nodeId}`}
              className="flex flex-col gap-xs rounded-md bg-canvas p-lg elevation-2 transition-shadow hover:elevation-4"
            >
              <div className="flex items-center justify-between gap-xs">
                <Text size="md" strong tone="ink">
                  {screenLabel(screen, index)}
                </Text>
                <Badge variant={screen.status === "implemented" ? "cyan" : "warning"} mono>
                  {screen.status.toUpperCase()}
                </Badge>
              </div>
              <span className="font-mono text-caption-mono text-mute">node-id {screen.nodeId}</span>
            </Link>
          </li>
        ))}
      </ol>
    </main>
  );
}
