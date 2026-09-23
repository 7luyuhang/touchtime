"use client";

import { useId, useRef, useState, type KeyboardEvent, type ReactNode } from "react";
import { cx } from "@/lib/cx";

export interface TabItem {
  value: string;
  label: ReactNode;
  content?: ReactNode;
}

export interface TabsProps {
  items: TabItem[];
  label: string;
  value?: string;
  defaultValue?: string;
  onValueChange?: (value: string) => void;
  className?: string;
}

/** DESIGN.md `tab-ghost`: 64px pill, body-sm label, 16px horizontal padding. */
export function Tabs({ items, label, value, defaultValue, onValueChange, className }: TabsProps) {
  const baseId = useId();
  const [uncontrolled, setUncontrolled] = useState(defaultValue ?? items[0]?.value);
  const selected = value ?? uncontrolled;
  const tabRefs = useRef<Array<HTMLButtonElement | null>>([]);

  const select = (next: string) => {
    if (value === undefined) setUncontrolled(next);
    onValueChange?.(next);
  };

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const keys: Record<string, number> = { ArrowRight: 1, ArrowLeft: -1 };
    const current = items.findIndex((item) => item.value === selected);
    let next: number | undefined;
    if (event.key in keys) next = (current + keys[event.key] + items.length) % items.length;
    if (event.key === "Home") next = 0;
    if (event.key === "End") next = items.length - 1;
    if (next === undefined) return;
    event.preventDefault();
    select(items[next].value);
    tabRefs.current[next]?.focus();
  };

  const selectedItem = items.find((item) => item.value === selected);

  return (
    <div className={className}>
      <div role="tablist" aria-label={label} onKeyDown={onKeyDown} className="flex flex-wrap gap-xs">
        {items.map((item, index) => {
          const isSelected = item.value === selected;
          return (
            <button
              key={item.value}
              ref={(node) => {
                tabRefs.current[index] = node;
              }}
              type="button"
              role="tab"
              id={`${baseId}-tab-${item.value}`}
              aria-selected={isSelected}
              aria-controls={item.content ? `${baseId}-panel` : undefined}
              tabIndex={isSelected ? 0 : -1}
              onClick={() => select(item.value)}
              className={cx(
                "h-control-sm rounded-pill-sm px-md text-body-sm transition-colors",
                isSelected
                  ? "bg-canvas text-ink elevation-2"
                  : "bg-transparent text-body hover:bg-canvas-soft-2 hover:text-ink",
              )}
            >
              {item.label}
            </button>
          );
        })}
      </div>
      {selectedItem?.content !== undefined && (
        <div
          role="tabpanel"
          id={`${baseId}-panel`}
          aria-labelledby={`${baseId}-tab-${selectedItem.value}`}
          tabIndex={0}
          className="mt-md"
        >
          {selectedItem.content}
        </div>
      )}
    </div>
  );
}
