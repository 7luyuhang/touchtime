import type { ComponentType } from "react";

export const FIGMA_FILE_KEY = "mRqDXY037g9l7zv89aZR8D";
export const FIGMA_FILE_URL = `https://www.figma.com/design/${FIGMA_FILE_KEY}/Hardware---watch`;

interface ScreenBase {
  /** Figma node id in URL form (`884-1631`), also used as the route slug. */
  nodeId: string;
  figmaUrl: string;
}

export interface BlockedScreen extends ScreenBase {
  status: "blocked";
  blockedReason: string;
}

export interface ImplementedScreen extends ScreenBase {
  status: "implemented";
  title: string;
  component: ComponentType;
}

export type ScreenEntry = BlockedScreen | ImplementedScreen;

const FIGMA_BLOCKED = "Figma frame not readable yet: the Figma MCP/API was not connected for this build.";

function blocked(nodeId: string): BlockedScreen {
  return {
    nodeId,
    figmaUrl: `${FIGMA_FILE_URL}?node-id=${nodeId}&m=dev`,
    status: "blocked",
    blockedReason: FIGMA_BLOCKED,
  };
}

/** Order matches the frame list in the brief. */
export const screens: ScreenEntry[] = [
  blocked("884-1631"),
  blocked("950-1697"),
  blocked("952-2642"),
  blocked("1154-2419"),
  blocked("986-4826"),
  blocked("976-4514"),
  blocked("975-4305"),
];

export function getScreen(nodeId: string): ScreenEntry | undefined {
  return screens.find((screen) => screen.nodeId === nodeId);
}

export function screenLabel(screen: ScreenEntry, index: number): string {
  return screen.status === "implemented" ? screen.title : `Screen ${index + 1}`;
}
