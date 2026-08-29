import { setActivePage, setActivePanel, useAppStore } from "@stores/app";
import type { PageKey, PanelKey } from "@stores/app";
import { Navigator } from "@components/Navigator";

export function BottomNavigator() {
  const pages = useAppStore((state) => state.pages);
  const panels = useAppStore((state) => state.panels);
  const activePage = useAppStore((state) => state.activePage);
  const activePanel = useAppStore((state) => state.activePanel);

  return (
    <Navigator ariaLabel="Primary navigation">
      {(Object.keys(pages) as PageKey[]).map((key) => {
        const { label, icon: Icon } = pages[key];

        return (
          <Navigator.Item
            key={key}
            label={label}
            icon={<Icon />}
            active={activePage === key}
            activeVariant="subtle"
            onClick={() => setActivePage(key)}
            iconOnly
          />
        );
      })}
      <Navigator.Divider />
      {(Object.keys(panels) as PanelKey[]).map((key) => {
        const { label, icon: Icon, iconOnly } = panels[key];
        const active = activePanel === key;

        return (
          <Navigator.Item
            key={key}
            label={label}
            icon={<Icon />}
            aria-label={`Toggle ${label.toLowerCase()}`}
            aria-expanded={active}
            active={active}
            onClick={() => setActivePanel(active ? null : key)}
            iconOnly={iconOnly}
          />
        );
      })}
    </Navigator>
  );
}
