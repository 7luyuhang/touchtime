import { HomeIndicator, ListeningHills, PageIndicator, Sheet, SplitControlBar, StatusBar, WatchScreen } from "@/components/watch";

/** 06 left: ambient listening with the split control bar. */
export function ListeningScreen() {
  return (
    <WatchScreen background="ambient" label="Listening">
      <StatusBar />
      <ListeningHills />
      <p
        className="absolute left-[115px] top-[217px] bg-clip-text text-watch-body text-transparent"
        style={{ backgroundImage: "linear-gradient(90deg, #fff 0%, #fff 74%, rgba(255,255,255,0.2) 100%)" }}
      >
        Listening...
      </p>
      <SplitControlBar />
      <HomeIndicator />
    </WatchScreen>
  );
}

/** 06 right: a recap sheet with its time header and page dots. */
export function RecapsScreen() {
  return (
    <WatchScreen background="black" label="Recaps">
      <StatusBar />
      <Sheet
        top={92}
        bottom={483}
        notchCenter={250}
        stack={{ count: 2, direction: "down" }}
        header={{
          height: 87,
          content: <p className="text-watch-body text-watch-label-secondary">9:00-9:30</p>,
        }}
      >
        <p className="absolute left-[32px] top-[120px] w-[344px] text-watch-title-strong">Competitor Analysis Discussion</p>
        <p className="absolute left-[32px] top-[217px] w-[322px] text-watch-body text-watch-label-secondary">
          Notes generated from weekly sync-up meeting
        </p>
      </Sheet>
      <PageIndicator count={3} active={0} className="left-[390px] top-[212px]" />
    </WatchScreen>
  );
}
