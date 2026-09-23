"use client";

import { useState } from "react";
import {
  AuroraWave,
  CameraGlyph,
  CaptureControlBar,
  CaptureWaves,
  HomeIndicator,
  NowPlayingPill,
  PhotoCard,
  RoundButton,
  WatchScreen,
} from "@/components/watch";

type CaptureMode = "idle" | "photo";

export interface CaptureScreenProps {
  variant?: "green" | "aurora";
  nowPlaying?: boolean;
  initialMode?: CaptureMode;
}

/**
 * 03 / 04 capture home. Interactive: the camera button opens the photo
 * preview (tap the photo to dismiss); record toggles a recording pulse.
 */
export function CaptureScreen({ variant = "green", nowPlaying = false, initialMode = "idle" }: CaptureScreenProps) {
  const [mode, setMode] = useState<CaptureMode>(initialMode);
  const [recording, setRecording] = useState(false);
  const photo = mode === "photo";

  return (
    <WatchScreen
      background={photo ? "photo" : variant === "aurora" ? "aurora" : "capture"}
      label={photo ? "Photo preview" : "Capture"}
    >
      {!photo && (variant === "aurora" ? <AuroraWave /> : <CaptureWaves />)}
      {!photo && (
        <div className="absolute left-[154px] top-[15px] z-10">
          <RoundButton
            size="lg"
            tone={variant === "aurora" ? "glass" : "mint"}
            label="Take photo"
            icon={<CameraGlyph />}
            onClick={() => setMode("photo")}
          />
        </div>
      )}
      {!photo && nowPlaying && (
        <NowPlayingPill
          title="Together"
          artist="Misha Panfilov"
          artwork="/samples/together-cover.png"
          className="absolute left-[16px] top-[163px] z-10"
        />
      )}
      {photo && (
        <button
          type="button"
          aria-label="Close photo"
          onClick={() => setMode("idle")}
          className="absolute left-[107px] top-[31px] z-20 rounded-watch-photo watch-press"
        >
          <PhotoCard src="/samples/office-photo.png" alt="Captured photo" />
        </button>
      )}
      <CaptureControlBar dimmed={photo} recording={recording} onRecord={() => setRecording((value) => !value)} />
      <HomeIndicator />
    </WatchScreen>
  );
}
