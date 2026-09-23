import { DocsNav } from "./_sections/docs-nav";

export default function DesignSystemLayout({ children }: LayoutProps<"/design-system">) {
  return (
    <div className="mx-auto flex max-w-page gap-2xl px-md tablet:px-lg">
      <aside className="sticky top-16 hidden h-[calc(100dvh-64px)] w-[220px] shrink-0 overflow-y-auto py-2xl desktop:block">
        <DocsNav />
      </aside>
      <main className="min-w-0 flex-1 pb-5xl pt-3xl">{children}</main>
    </div>
  );
}
