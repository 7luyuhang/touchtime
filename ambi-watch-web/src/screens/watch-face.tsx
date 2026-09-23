import { ListeningWaveform, OutlineClock, WatchScreen } from "@/components/watch";

/** 01 left: outline numerals on black. */
export function WatchFaceScreen() {
  return (
    <WatchScreen label="Watch face">
      <OutlineClock hours={["1", "0"]} minutes={["0", "9"]} className="absolute left-[76px] top-[81px] text-watch-white" />
    </WatchScreen>
  );
}

/** 01 right: numerals dim and shrink while a green panel with the live waveform rises. */
export function WatchFaceListeningScreen() {
  return (
    <WatchScreen label="Watch face, listening">
      <div className="absolute inset-x-0 top-0 bottom-[8px] rounded-b-[92px] watch-gradient-ambient shadow-[inset_0_-2px_0_rgba(150,215,185,0.55)]" />
      <OutlineClock
        hours={["1", "0"]}
        minutes={["0", "9"]}
        cellWidth={94}
        className="absolute left-[106px] top-[61px] text-watch-label-dim"
      />
      <ListeningWaveform />
    </WatchScreen>
  );
}
