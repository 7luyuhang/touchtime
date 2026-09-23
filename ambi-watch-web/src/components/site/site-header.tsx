import Link from "next/link";
import { ThemeToggle } from "./theme-toggle";

const links = [
  { href: "/design-system", label: "Design system" },
  { href: "/screens", label: "Screens" },
];

/** DESIGN.md `nav-bar`: 64px, canvas, body-sm links as ghost pills. */
export function SiteHeader() {
  return (
    <header className="sticky top-0 z-10 border-b border-hairline bg-canvas">
      <div className="mx-auto flex h-16 max-w-page items-center justify-between gap-md px-md tablet:px-lg">
        <Link href="/" className="whitespace-nowrap text-body-md-strong text-ink">
          ambi watch
        </Link>
        <nav className="flex items-center gap-xxs">
          {links.map((link) => (
            <Link
              key={link.href}
              href={link.href}
              className="whitespace-nowrap rounded-full px-xs py-xs text-body-sm text-body transition-colors tablet:px-sm hover:bg-canvas-soft-2 hover:text-ink"
            >
              {link.label}
            </Link>
          ))}
          <span className="ml-xs hidden tablet:inline">
            <ThemeToggle />
          </span>
        </nav>
      </div>
    </header>
  );
}
