"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cx } from "@/lib/cx";

const sections = [
  {
    href: "/design-system",
    label: "Foundations",
    anchors: [
      { id: "screen", label: "Screen" },
      { id: "watch-color", label: "Color & gradients" },
      { id: "materials", label: "Materials" },
      { id: "watch-type", label: "Typography" },
      { id: "watch-shape", label: "Radius, sizes, motion" },
      { id: "color", label: "Vercel color" },
      { id: "typography", label: "Vercel type" },
      { id: "spacing", label: "Spacing & radius" },
      { id: "elevation", label: "Elevation & motion" },
    ],
  },
  { href: "/design-system/controls", label: "Base controls", anchors: [] },
  { href: "/design-system/watch", label: "Watch components", anchors: [] },
  { href: "/screens", label: "Screens", anchors: [] },
];

export function DocsNav() {
  const pathname = usePathname();
  return (
    <nav aria-label="Design system" className="flex flex-col gap-md">
      {sections.map((section) => {
        const active = pathname === section.href;
        return (
          <div key={section.href} className="flex flex-col gap-xxs">
            <Link
              href={section.href}
              aria-current={active ? "page" : undefined}
              className={cx(
                "rounded-sm px-sm py-xs text-body-sm transition-colors",
                active ? "bg-canvas text-ink elevation-1" : "text-body hover:text-ink",
              )}
            >
              {section.label}
            </Link>
            {active &&
              section.anchors.map((anchor) => (
                <a
                  key={anchor.id}
                  href={`#${anchor.id}`}
                  className="ml-sm border-l border-hairline py-xxs pl-sm text-body-sm text-mute transition-colors hover:text-ink"
                >
                  {anchor.label}
                </a>
              ))}
          </div>
        );
      })}
    </nav>
  );
}
