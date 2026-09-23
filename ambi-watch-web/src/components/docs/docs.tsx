import type { ReactNode } from "react";
import { Badge, type BadgeVariant } from "@/components/primitives/badge";
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

const statusBadges: Record<AmbiTokenStatus | "vercel" | "provisional", { variant: BadgeVariant; label: string }> = {
  sampled: { variant: "cyan", label: "SAMPLED" },
  assumed: { variant: "warning", label: "ASSUMED" },
  provisional: { variant: "violet", label: "PROVISIONAL" },
  vercel: { variant: "secondary", label: "VERCEL" },
};

export function StatusBadge({ status }: { status: AmbiTokenStatus | "vercel" | "provisional" }) {
  const { variant, label } = statusBadges[status];
  return (
    <Badge variant={variant} mono>
      {label}
    </Badge>
  );
}

/** Scales a 410×502 watch screen for inline documentation. */
export function ScreenStage({ scale = 0.6, children, caption }: { scale?: number; children: ReactNode; caption?: string }) {
  return (
    <figure className="flex flex-col gap-xs">
      <div className="relative shrink-0" style={{ width: 410 * scale, height: 502 * scale }}>
        <div className="absolute left-0 top-0 origin-top-left" style={{ transform: `scale(${scale})` }}>
          {children}
        </div>
      </div>
      {caption && <figcaption className="font-mono text-caption-mono text-mute">{caption}</figcaption>}
    </figure>
  );
}

/** Near-black panel for showing watch components at 1:1 outside a screen. */
export function DarkStage({ children, className }: { children: ReactNode; className?: string }) {
  return (
    <div className={`flex flex-wrap items-center gap-lg rounded-lg bg-watch-black p-xl font-watch text-watch-white ${className ?? ""}`}>
      {children}
    </div>
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
