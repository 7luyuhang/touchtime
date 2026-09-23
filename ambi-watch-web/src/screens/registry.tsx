import type { ComponentType } from "react";
import { CaptureScreen } from "./capture";
import { ListeningScreen, RecapsScreen } from "./listening";
import { PowerOffScreen } from "./power-off";
import { QuickActionsScreen, QuickActionsScrolledScreen, QuickTodoScreen } from "./quick-actions";
import { WatchFaceListeningScreen, WatchFaceScreen } from "./watch-face";

export type ScreenGroup = "Watch face" | "Quick actions" | "Capture" | "Power off" | "Listening";

export interface ScreenEntry {
  slug: string;
  title: string;
  group: ScreenGroup;
  /** Reference image and position within it, e.g. "02-quick-actions.png · 1 of 3". */
  source: string;
  /** 410×502 crop of the reference screen, served from /public. */
  reference: string;
  component: ComponentType;
  interaction?: string;
  notes?: string;
}

function entry(slug: string, rest: Omit<ScreenEntry, "slug" | "reference">): ScreenEntry {
  return { slug, reference: `/references/${slug}.png`, ...rest };
}

export const screens: ScreenEntry[] = [
  entry("watch-face", {
    title: "Watch face",
    group: "Watch face",
    source: "01-watch-face-time-and-listening.png · 1 of 2",
    component: WatchFaceScreen,
  }),
  entry("watch-face-listening", {
    title: "Watch face · listening",
    group: "Watch face",
    source: "01-watch-face-time-and-listening.png · 2 of 2",
    component: WatchFaceListeningScreen,
  }),
  entry("quick-actions", {
    title: "Quick actions",
    group: "Quick actions",
    source: "02-quick-actions.png · 1 of 3",
    component: QuickActionsScreen,
    interaction: "Scroll the list to reveal “Summary emails”.",
  }),
  entry("quick-actions-scrolled", {
    title: "Quick actions · detail cards",
    group: "Quick actions",
    source: "02-quick-actions.png · 2 of 3",
    component: QuickActionsScrolledScreen,
    notes: "Treated as a second card layout (icon lifted above the card); the image does not say whether it is a scrolled state.",
  }),
  entry("quick-todo", {
    title: "Quick todo",
    group: "Quick actions",
    source: "02-quick-actions.png · 3 of 3",
    component: QuickTodoScreen,
    interaction: "Scroll inside the sheet to move the scroll indicator.",
  }),
  entry("capture", {
    title: "Capture",
    group: "Capture",
    source: "03-capture-controls-now-playing-photo.png · 1 of 3",
    component: () => <CaptureScreen />,
    interaction: "Camera opens the photo preview; record toggles a pulse.",
  }),
  entry("capture-now-playing", {
    title: "Capture · now playing",
    group: "Capture",
    source: "03-capture-controls-now-playing-photo.png · 2 of 3",
    component: () => <CaptureScreen nowPlaying />,
  }),
  entry("capture-photo", {
    title: "Capture · photo preview",
    group: "Capture",
    source: "03-capture-controls-now-playing-photo.png · 3 of 3",
    component: () => <CaptureScreen initialMode="photo" />,
    interaction: "Tap the photo to return to capture.",
    notes: "Photo and album art are cropped from the reference as sample content.",
  }),
  entry("capture-aurora", {
    title: "Capture · aurora",
    group: "Capture",
    source: "04-capture-home.png",
    component: () => <CaptureScreen variant="aurora" />,
  }),
  entry("power-off-1", {
    title: "Power off · slide",
    group: "Power off",
    source: "05-power-off-flow.png · 1 of 4",
    component: () => <PowerOffScreen initialStep={1} />,
    interaction: "Drag the knob down to arm; it then settles into the hint state.",
  }),
  entry("power-off-2", {
    title: "Power off · armed",
    group: "Power off",
    source: "05-power-off-flow.png · 2 of 4",
    component: () => <PowerOffScreen initialStep={2} />,
  }),
  entry("power-off-3", {
    title: "Power off · press & hold",
    group: "Power off",
    source: "05-power-off-flow.png · 3 of 4",
    component: () => <PowerOffScreen initialStep={3} />,
    interaction: "Press and hold the power knob to reach step 4.",
  }),
  entry("power-off-4", {
    title: "Power off · side by side",
    group: "Power off",
    source: "05-power-off-flow.png · 4 of 4",
    component: () => <PowerOffScreen initialStep={4} />,
    notes: "Step 4’s meaning (hold in progress vs. alternate layout) is not stated; the back triangle resets the flow.",
  }),
  entry("listening", {
    title: "Listening",
    group: "Listening",
    source: "06-listening-and-recaps.png · Listening",
    component: ListeningScreen,
  }),
  entry("recaps", {
    title: "Recaps",
    group: "Listening",
    source: "06-listening-and-recaps.png · Recaps",
    component: RecapsScreen,
  }),
];

export const screenGroups: ScreenGroup[] = ["Watch face", "Quick actions", "Capture", "Power off", "Listening"];

export function getScreen(slug: string): ScreenEntry | undefined {
  return screens.find((screen) => screen.slug === slug);
}
