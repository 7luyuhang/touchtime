import type { ReactNode } from "react";
import { Badge } from "@/components/primitives/badge";
import { Eyebrow, Heading, Text } from "@/components/primitives/text";
import type { AmbiTokenStatus } from "@/tokens/types";

export function DocSection({
  id,
  layer,
  title,
  description,
  children,
}: {
  id: string;
  layer: string;
  title: string;
  description?: ReactNode;
  children: ReactNode;
}) {
  return (
    <section id={id} className="scroll-mt-20 border-t border-hairline py-3xl">
      <div className="mb-xl flex max-w-[720px] flex-col gap-xs">
        <Eyebrow>{layer}</Eyebrow>
        <Heading size="md">{title}</Heading>
        {description && <Text>{description}</Text>}
      </div>
      <div className="flex flex-col gap-2xl">{children}</div>
    </section>
  );
}

export function DocGroup({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-md">
      <Text size="sm" strong tone="ink">
        {title}
      </Text>
      {children}
    </div>
  );
}

export function DemoRow({ label, children }: { label?: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-sm">
      {label && <p className="font-mono text-caption-mono text-mute">{label}</p>}
      <div className="flex flex-wrap items-center gap-sm">{children}</div>
    </div>
  );
}

export function StatusBadge({ status }: { status: AmbiTokenStatus | "vercel" | "provisional" }) {
  if (status === "placeholder")
    return (
      <Badge variant="warning" mono>
        PLACEHOLDER
      </Badge>
    );
  if (status === "provisional")
    return (
      <Badge variant="violet" mono>
        PROVISIONAL
      </Badge>
    );
  if (status === "figma")
    return (
      <Badge variant="cyan" mono>
        FIGMA
      </Badge>
    );
  return (
    <Badge variant="secondary" mono>
      VERCEL
    </Badge>
  );
}

export function Swatch({ name, light, dark }: { name: string; light: string; dark?: string }) {
  return (
    <div className="flex flex-col gap-xs">
      <div className="h-16 rounded-md elevation-1" style={{ background: `var(--color-${name})` }} />
      <div className="flex flex-col">
        <span className="font-mono text-caption-mono text-ink">{name}</span>
        <span className="font-mono text-caption-mono text-mute">
          {light}
          {dark && ` / ${dark}`}
        </span>
      </div>
    </div>
  );
}

export function SpecTable({ head, rows }: { head: string[]; rows: ReactNode[][] }) {
  return (
    <div className="overflow-x-auto rounded-md bg-canvas elevation-1">
      <table className="w-full border-collapse text-left">
        <thead className="bg-canvas-soft">
          <tr>
            {head.map((cell) => (
              <th key={cell} className="px-sm py-xs font-mono text-caption-mono font-regular uppercase text-mute">
                {cell}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row, rowIndex) => (
            <tr key={rowIndex} className="border-t border-hairline">
              {row.map((cell, cellIndex) => (
                <td key={cellIndex} className="px-sm py-xs align-middle text-body-sm text-body">
                  {cell}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
