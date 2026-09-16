import React, { useMemo } from 'react';
import { useAppSelector } from '../../store';
import { RightPanelMode, selectNavPanels } from '../../store/navPanels';

export type { RightPanelMode };

interface InventoryNavProps {
  mode: RightPanelMode;
  onChange: (mode: RightPanelMode) => void;
}

const icons: Record<RightPanelMode, React.ReactNode> = {
  inventory: (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M8 3a2 2 0 0 0-2 2v1H5a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-1V5a2 2 0 0 0-2-2H8zm0 2h8v1H8V5zm-3 3h14v11H5V8zm3 3v2h8v-2H8z" />
    </svg>
  ),
  craft: (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M2 19.5 12.5 9l2.5 2.5L4.5 22 2 19.5zM15.5 3.5a3.5 3.5 0 0 1 4.95 4.95l-1.4 1.4-4.95-4.95 1.4-1.4zM13.4 8.1l2.5 2.5 1.4-1.4-2.5-2.5-1.4 1.4z" />
    </svg>
  ),
  wearables: (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M12 12a4 4 0 1 0-4-4 4 4 0 0 0 4 4zm0 1.5c-3.6 0-8 1.8-8 5.4V21h16v-2.1c0-3.6-4.4-5.4-8-5.4z" />
    </svg>
  ),
  settings: (
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
      <path d="M19.1 12.9a7.4 7.4 0 0 0 .1-1.8l2-1.6-1.9-3.3-2.4.8a7.2 7.2 0 0 0-1.6-.9L14.9 3h-3.8l-.4 2.6a7.2 7.2 0 0 0-1.6.9l-2.4-.8L4.8 9.5l2 1.6a7.4 7.4 0 0 0 0 1.8l-2 1.6 1.9 3.3 2.4-.8c.5.4 1 .7 1.6.9l.4 2.6h3.8l.4-2.6c.6-.2 1.1-.5 1.6-.9l2.4.8 1.9-3.3-2-1.6zM12 15.2A3.2 3.2 0 1 1 15.2 12 3.2 3.2 0 0 1 12 15.2z" />
    </svg>
  ),
};

const ALL_TABS: { id: RightPanelMode; label: string }[] = [
  { id: 'inventory', label: 'Inventory' },
  { id: 'craft', label: 'Quick Craft' },
  { id: 'wearables', label: 'Wearables' },
  { id: 'settings', label: 'Settings' },
];

/** Vertical tab strip that swaps the right inventory panel */
const InventoryNav: React.FC<InventoryNavProps> = ({ mode, onChange }) => {
  const panels = useAppSelector(selectNavPanels);

  const tabs = useMemo(
    () =>
      ALL_TABS.filter((tab) => {
        if (tab.id === 'inventory') return true;
        return panels[tab.id];
      }),
    [panels]
  );

  // Nothing optional enabled — hide the whole column
  if (tabs.length <= 1) return null;

  return (
    <nav className="inventory-nav" aria-label="Inventory panels">
      {tabs.map((tab) => (
        <button
          key={tab.id}
          type="button"
          className={`inventory-nav-btn${mode === tab.id ? ' inventory-nav-btn-active' : ''}`}
          title={tab.label}
          aria-label={tab.label}
          aria-pressed={mode === tab.id}
          onClick={() => onChange(tab.id)}
        >
          {icons[tab.id]}
        </button>
      ))}
    </nav>
  );
};

export default InventoryNav;
