import type { ReactNode } from "react";
import { DocSection, ScreenStage } from "@/components/docs/docs";
import { Code, Text } from "@/components/primitives";
import {
  AuroraWave,
  BackTriangleGlyph,
  CameraGlyph,
  CaptureControlBar,
  CaptureWaves,
  ChevronDownGlyph,
  CloseGlyph,
  GmailIcon,
  HomeIndicator,
  ListCard,
  ListeningHills,
  ListeningWaveform,
  NotificationCard,
  NowPlayingPill,
  OutlineClock,
  PageIndicator,
  PlusGlyph,
  PowerGlyph,
  PowerPair,
  PowerSlider,
  RecordGlyph,
  RoundButton,
  ScreenHeader,
  ScrollIndicator,
  Sheet,
  SplitControlBar,
  StatusBar,
  StopGlyph,
  TodoGlyph,
  WatchScreen,
} from "@/components/watch";

function Spec({ name, file, children, description }: { name: string; file: string; description: string; children: ReactNode }) {
  return (
    <div className="flex flex-col gap-md border-t border-hairline pt-lg">
      <div className="flex flex-wrap items-baseline justify-between gap-xs">
        <Text size="md" strong tone="ink">
          {name}
        </Text>
        <Code>{file}</Code>
      </div>
      <Text size="sm" className="max-w-[720px]">
        {description}
      </Text>
      <div className="flex flex-wrap items-start gap-xl">{children}</div>
    </div>
  );
}

function Panel({ background = "ambient", children, width = 410, height = 180 }: { background?: string; children: ReactNode; width?: number; height?: number }) {
  return (
    <div
      className="relative flex items-center justify-center overflow-hidden rounded-lg font-watch text-watch-white"
      style={{ width, height, background: `var(--gradient-watch-${background})` }}
    >
      {children}
    </div>
  );
}

export function WatchComponentsSection() {
  return (
    <DocSection
      id="watch-components"
      layer="Components · ambi watch"
      title="Watch components."
      description="Composed from the watch tokens. Components that live at fixed screen positions are shown inside a 410×502 screen at reduced scale."
    >
      <Spec
        name="RoundButton"
        file="round-button.tsx"
        description="Circular glass button. 80px (40pt) for close/back, 102px (51pt) for the camera. Tone sets the rim: glass, mint, red."
      >
        <Panel background="capture">
          <div className="flex items-center gap-lg">
            <RoundButton label="Close" icon={<CloseGlyph />} />
            <RoundButton size="lg" tone="mint" label="Take photo" icon={<CameraGlyph />} />
          </div>
        </Panel>
        <Panel background="power" width={200}>
          <RoundButton tone="red" label="Cancel" icon={<BackTriangleGlyph size={27} className="-translate-x-[2px]" />} />
        </Panel>
      </Spec>

      <Spec
        name="StatusBar · ScreenHeader"
        file="status-bar.tsx"
        description="92px (46pt) top area with the time centred, or the quick-actions header: close button left, time and serif title right-aligned."
      >
        <ScreenStage scale={0.5} caption="StatusBar">
          <WatchScreen background="ambient">
            <StatusBar />
          </WatchScreen>
        </ScreenStage>
        <ScreenStage scale={0.5} caption="ScreenHeader">
          <WatchScreen background="ambient">
            <ScreenHeader title="Quick Actions" />
          </WatchScreen>
        </ScreenStage>
      </Spec>

      <Spec
        name="CaptureControlBar · SplitControlBar"
        file="control-bar.tsx"
        description="Record / stop / add as three 102px circles joined by 38px necks (metaball path), dimmed behind the photo preview. The listening variant is two pill segments pinched together."
      >
        <ScreenStage scale={0.5} caption="CaptureControlBar">
          <WatchScreen background="capture">
            <CaptureControlBar />
          </WatchScreen>
        </ScreenStage>
        <ScreenStage scale={0.5} caption="dimmed">
          <WatchScreen background="photo">
            <CaptureControlBar dimmed />
          </WatchScreen>
        </ScreenStage>
        <ScreenStage scale={0.5} caption="SplitControlBar">
          <WatchScreen background="ambient">
            <SplitControlBar />
          </WatchScreen>
        </ScreenStage>
      </Spec>

      <Spec
        name="ListCard"
        file="list-card.tsx"
        description="Thin-glass pill, 394×110, title 32px and optional 28px subtitle. The stacked layout lifts a 56px app icon over the top edge."
      >
        <Panel height={300} width={410}>
          <div className="flex w-[394px] flex-col gap-[10px]">
            <ListCard title="Check email" icon={<GmailIcon size={48} radius={12} />} />
            <ListCard title="Draft reply" subtitle="Ambi ui design work" icon={<GmailIcon size={48} radius={12} />} />
          </div>
        </Panel>
        <Panel height={300} width={410}>
          <div className="w-[394px]">
            <ListCard layout="stacked" title="Summary emails" subtitle="Today’s emails" icon={<GmailIcon size={56} radius={14} />} />
          </div>
        </Panel>
      </Spec>

      <Spec
        name="NotificationCard · NowPlayingPill"
        file="notification-card.tsx · now-playing.tsx"
        description="Light 378×148 card with 40px corners for incoming items; 376×142 glass pill with 78px artwork for media."
      >
        <Panel background="black" height={200}>
          <NotificationCard title="Draft reply" subtitle="Ambi project" icon={<GmailIcon size={56} radius={14} />} />
        </Panel>
        <Panel background="capture" height={200}>
          <NowPlayingPill title="Together" artist="Misha Panfilov" artwork="/samples/together-cover.png" />
        </Panel>
      </Spec>

      <Spec
        name="Sheet"
        file="sheet.tsx"
        description="Full-width card whose right edge bows 33px inward around the crown-side indicator, with stacked layers 8px apart above or below. Optional time header."
      >
        <ScreenStage scale={0.5} caption="notch + stack up">
          <WatchScreen>
            <Sheet top={255} bottom={483} radiusTop={48} notchCenter={250} stack={{ count: 2, direction: "up" }} />
            <ScrollIndicator progress={0} className="left-[399px] top-[206px]" />
          </WatchScreen>
        </ScreenStage>
        <ScreenStage scale={0.5} caption="header + stack down">
          <WatchScreen>
            <Sheet
              top={92}
              bottom={483}
              notchCenter={250}
              stack={{ count: 2, direction: "down" }}
              header={{ height: 87, content: <p className="text-watch-body text-watch-label-secondary">9:00-9:30</p> }}
            />
            <PageIndicator count={3} active={0} className="left-[390px] top-[212px]" />
          </WatchScreen>
        </ScreenStage>
      </Spec>

      <Spec
        name="Indicators"
        file="indicators.tsx"
        description="PageIndicator (12px active / 8px inactive dots, 25px pitch), ScrollIndicator (10×90 track, 30px thumb) and HomeIndicator (72×8, 13px from the bottom)."
      >
        <Panel background="black" width={200} height={140}>
          <PageIndicator count={3} active={1} className="left-[60px] top-[32px]" />
          <ScrollIndicator progress={0.4} className="left-[130px] top-[25px]" />
        </Panel>
        <Panel background="capture" width={200} height={140}>
          <HomeIndicator />
        </Panel>
      </Spec>

      <Spec
        name="PowerSlider · PowerPair"
        file="power.tsx"
        description="Slide the 160px knob down a 192×376 track to arm; the armed state merges a back circle with the ring around the knob (metaball path), in vertical and horizontal arrangements."
      >
        <ScreenStage scale={0.45} caption="PowerSlider">
          <WatchScreen background="power">
            <PowerSlider />
          </WatchScreen>
        </ScreenStage>
        <ScreenStage scale={0.45} caption="armed">
          <WatchScreen background="power">
            <PowerPair layout="armed" />
          </WatchScreen>
        </ScreenStage>
        <ScreenStage scale={0.45} caption="hint">
          <WatchScreen background="power">
            <PowerPair layout="hint" />
          </WatchScreen>
        </ScreenStage>
        <ScreenStage scale={0.45} caption="horizontal">
          <WatchScreen background="power">
            <PowerPair layout="horizontal" />
          </WatchScreen>
        </ScreenStage>
      </Spec>

      <Spec
        name="OutlineClock · ListeningWaveform"
        file="clock-face.tsx · waveform.tsx"
        description="Outline numerals on a 40px module (4px stroke, 124×164 cells, 13px gaps); only 0, 1 and 9 exist in the references. The waveform steps fade in from the left into a mint stop button."
      >
        <ScreenStage scale={0.5} caption="OutlineClock">
          <WatchScreen>
            <OutlineClock hours={["1", "0"]} minutes={["0", "9"]} className="absolute left-[76px] top-[81px]" />
          </WatchScreen>
        </ScreenStage>
        <ScreenStage scale={0.5} caption="ListeningWaveform">
          <WatchScreen background="ambient">
            <ListeningWaveform />
          </WatchScreen>
        </ScreenStage>
      </Spec>

      <Spec
        name="Ambient backdrops"
        file="ambient.tsx"
        description="Decorative light threads and hills drawn over the context gradients."
      >
        <ScreenStage scale={0.4} caption="CaptureWaves">
          <WatchScreen background="capture">
            <CaptureWaves />
          </WatchScreen>
        </ScreenStage>
        <ScreenStage scale={0.4} caption="AuroraWave">
          <WatchScreen background="aurora">
            <AuroraWave />
          </WatchScreen>
        </ScreenStage>
        <ScreenStage scale={0.4} caption="ListeningHills">
          <WatchScreen background="ambient">
            <ListeningHills />
          </WatchScreen>
        </ScreenStage>
      </Spec>

      <Spec name="Glyphs" file="watch-icons.tsx" description="Drawn at their measured sizes in currentColor.">
        <Panel background="black" width={620} height={140}>
          <div className="flex items-center gap-lg">
            <CloseGlyph />
            <CameraGlyph />
            <PlusGlyph />
            <RecordGlyph className="text-watch-red" />
            <StopGlyph />
            <PowerGlyph />
            <BackTriangleGlyph />
            <ChevronDownGlyph />
            <TodoGlyph />
            <GmailIcon size={48} radius={12} />
          </div>
        </Panel>
      </Spec>
    </DocSection>
  );
}
