"use client";

import { useState, type UIEvent } from "react";
import {
  GmailIcon,
  HomeIndicator,
  ListCard,
  NotificationCard,
  ScreenHeader,
  ScrollIndicator,
  Sheet,
  StatusBar,
  TodoGlyph,
  WatchScreen,
} from "@/components/watch";

const actions = [
  { title: "Check email", icon: true },
  { title: "New todo" },
  { title: "Draft reply", subtitle: "Ambi ui design work", icon: true },
  { title: "Summary emails", subtitle: "Today’s emails", icon: true },
];

/** 02 left: header plus a scrollable list of pill cards. */
export function QuickActionsScreen() {
  return (
    <WatchScreen background="ambient" label="Quick actions">
      <ScreenHeader title="Quick Actions" />
      <div
        className="no-scrollbar absolute inset-x-0 bottom-0 top-[126px] overflow-y-auto overscroll-contain px-[8px] pb-[48px] pt-[9px]"
        style={{ maskImage: "linear-gradient(transparent 0, #000 12px)" }}
      >
        <div className="flex flex-col gap-[10px]">
          {actions.map((action) => (
            <ListCard
              key={action.title}
              title={action.title}
              subtitle={action.subtitle}
              icon={action.icon ? <GmailIcon size={48} radius={12} /> : undefined}
            />
          ))}
        </div>
      </div>
    </WatchScreen>
  );
}

/** 02 middle: the same list with icons lifted above each card. */
export function QuickActionsScrolledScreen() {
  return (
    <WatchScreen background="ambient" label="Quick actions, detail cards">
      <ScreenHeader title="Quick Actions" />
      <div className="absolute inset-x-[8px] top-[135px] flex flex-col gap-[18px]">
        {actions.slice(2).map((action) => (
          <ListCard
            key={action.title}
            layout="stacked"
            title={action.title}
            subtitle={action.subtitle}
            icon={<GmailIcon size={56} radius={14} />}
          />
        ))}
      </div>
    </WatchScreen>
  );
}

/** 02 right: incoming notification over a stack of cards; the front sheet scrolls. */
export function QuickTodoScreen() {
  const [progress, setProgress] = useState(0);
  const onScroll = (event: UIEvent<HTMLDivElement>) => {
    const el = event.currentTarget;
    const max = el.scrollHeight - el.clientHeight;
    setProgress(max > 0 ? el.scrollTop / max : 0);
  };

  return (
    <WatchScreen background="black" label="Quick todo">
      <StatusBar />
      <NotificationCard
        title="Draft reply"
        subtitle="Ambi project"
        icon={<GmailIcon size={56} radius={14} />}
        className="absolute left-[16px] top-[90px] z-10"
      />
      <Sheet top={255} bottom={483} radiusTop={48} notchCenter={250} stack={{ count: 2, direction: "up" }}>
        <div onScroll={onScroll} className="no-scrollbar absolute inset-0 overflow-y-auto">
          <div className="relative h-[300px]">
            <TodoGlyph className="absolute left-[38px] top-[38px] text-watch-white" />
            <p className="absolute left-[32px] top-[89px] text-watch-title">Quick todo</p>
            <p className="absolute left-[32px] top-[131px] w-[322px] text-watch-body text-watch-label-secondary">
              Amie watch interface project
            </p>
          </div>
        </div>
      </Sheet>
      <ScrollIndicator progress={progress} className="left-[399px] top-[206px]" />
      <HomeIndicator />
    </WatchScreen>
  );
}
