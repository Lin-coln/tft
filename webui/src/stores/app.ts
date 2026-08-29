import { create } from "zustand";
import type { IconType } from "react-icons";
import {
  HiOutlineChartBar,
  HiOutlineCog6Tooth,
  HiOutlineHome,
  HiOutlineQueueList,
  HiOutlineSquare2Stack,
} from "react-icons/hi2";

export type PageKey = "overview" | "timeline" | "snapshots";
export type PanelKey = "state" | "inspector" | "settings";

const store = create<{
  pages: Record<
    PageKey,
    {
      label: string;
      icon: IconType;
    }
  >;
  panels: Record<
    PanelKey,
    {
      label: string;
      icon: IconType;
      iconOnly?: boolean;
    }
  >;
  activePage: PageKey;
  activePanel: PanelKey | null;
}>(() => ({
  pages: {
    overview: { label: "Overview", icon: HiOutlineHome },
    timeline: { label: "Timeline", icon: HiOutlineChartBar },
    snapshots: { label: "Snapshots", icon: HiOutlineSquare2Stack },
  },
  panels: {
    state: { label: "State", icon: HiOutlineSquare2Stack },
    inspector: { label: "Inspector", icon: HiOutlineQueueList },
    settings: { label: "Settings", icon: HiOutlineCog6Tooth, iconOnly: true },
  },
  activePage: "overview",
  activePanel: null,
}));

export const useAppStore = store;

export function setActivePage(page: PageKey) {
  store.setState({ activePage: page });
}

export function setActivePanel(panel: PanelKey | null) {
  store.setState({ activePanel: panel });
}
