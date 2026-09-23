"use client";

import { useState } from "react";
import { Button } from "@/components/primitives/button";
import type { ThemeName } from "@/tokens/themes";

export function ThemeToggle() {
  const [theme, setTheme] = useState<ThemeName>("light");

  const toggle = () => {
    const next: ThemeName = theme === "light" ? "dark" : "light";
    document.documentElement.dataset.theme = next;
    setTheme(next);
  };

  return (
    <Button variant="secondary" size="xs" shape="rounded" onClick={toggle} aria-pressed={theme === "dark"}>
      {theme === "light" ? "Dark surface" : "Light surface"}
    </Button>
  );
}
