import React, { useMemo, useState } from 'react';
import { isEnvBrowser } from '../../utils/misc';

export type WearableSlotId = 'mask' | 'watch' | 'backpack' | 'armour' | 'holster';

type WearableDef = {
  id: WearableSlotId;
  label: string;
  /** Extra container slots when this piece is equipped + selected */
  storageSlots?: number;
  icon: React.ReactNode;
};

const WEARABLES: WearableDef[] = [
  {
    id: 'mask',
    label: 'Mask',
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 3c-4.5 0-8 2.7-8 7v2.2c0 1.5.8 2.9 2.1 3.7L7 20h2l.8-2.2c.7.1 1.4.2 2.2.2s1.5-.1 2.2-.2L15 20h2l.9-4.1c1.3-.8 2.1-2.2 2.1-3.7V10c0-4.3-3.5-7-8-7zm-3.2 8.2a1.3 1.3 0 1 1 0-2.6 1.3 1.3 0 0 1 0 2.6zm6.4 0a1.3 1.3 0 1 1 0-2.6 1.3 1.3 0 0 1 0 2.6zM9.5 14.2c.7.6 1.6.9 2.5.9s1.8-.3 2.5-.9c.2-.2.2-.5 0-.7-.2-.2-.5-.2-.7 0-.5.4-1.1.6-1.8.6s-1.3-.2-1.8-.6c-.2-.2-.5-.2-.7 0-.2.2-.2.5 0 .7z" />
      </svg>
    ),
  },
  {
    id: 'watch',
    label: 'Watch',
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M9 2h6l1 4H8L9 2zm0 20 1-4h4l1 4H9zm3-15a6 6 0 1 1 0 12 6 6 0 0 1 0-12zm0 2a4 4 0 1 0 0 8 4 4 0 0 0 0-8zm-.8 1.5h1.3v2.4l1.7 1.7-.9.9-2.1-2.1V10.5z" />
      </svg>
    ),
  },
  {
    id: 'backpack',
    label: 'Backpack',
    storageSlots: 10,
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M8 6V5a4 4 0 0 1 8 0v1h2a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2zm2 0h4V5a2 2 0 0 0-4 0v1zm-3 4v3h4v-1.5h2V13h4V10H7zm0 5v4h10v-4h-4v1.5h-2V15H7z" />
      </svg>
    ),
  },
  {
    id: 'armour',
    label: 'Armour',
    storageSlots: 3,
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 2 4 5v6.5c0 5.1 3.4 9.4 8 10.5 4.6-1.1 8-5.4 8-10.5V5l-8-3zm0 2.2 6 2.2v5.1c0 3.9-2.5 7.2-6 8.3-3.5-1.1-6-4.4-6-8.3V6.4l6-2.2zm-3 5.3h6v2H9v-2zm0 3.5h6v2H9v-2z" />
      </svg>
    ),
  },
  {
    id: 'holster',
    label: 'Holster',
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M7 3h7l3 4v3.5l-2 1V21H9v-9.5l-2-1V7l0-4zm2 2v2h6.2L16 5H9zm1 6.2V19h4v-7.8l2-.9V8H8v2.3l2 .9z" />
      </svg>
    ),
  },
];

/** Browser-only mock: which wearables look "equipped" in Vite preview */
const DEBUG_EQUIPPED: Partial<Record<WearableSlotId, boolean>> = isEnvBrowser()
  ? { backpack: true, armour: true }
  : {};

/** Empty storage cells for backpack / armour containers */
const StorageGrid: React.FC<{ slots: number; locked: boolean; label: string }> = ({
  slots,
  locked,
  label,
}) => {
  // Prefer a tall column layout (2×5 backpack, 1×3 armour) over a wide row
  const cols = slots > 5 ? 2 : 1;

  return (
    <div className={`wearables-storage${locked ? ' wearables-storage-locked' : ''}`}>
      <p className="wearables-storage-label">
        {locked ? `Equip a ${label.toLowerCase()} to use storage` : `${label} storage`}
      </p>
      <div
        className="wearables-storage-grid"
        style={{ gridTemplateColumns: `repeat(${cols}, var(--wearable-slot-size, 9.6vh))` }}
      >
        {Array.from({ length: slots }, (_, i) => (
          <div key={i} className="wearables-storage-slot" />
        ))}
      </div>
    </div>
  );
};

/**
 * Wearables column + detail pane.
 * Preview is the live ped (scripted camera); backpack/armour reveal extra slots when selected.
 */
const WearablesPanel: React.FC = () => {
  const [selected, setSelected] = useState<WearableSlotId | null>(null);
  // Equip state will come from the game later; mock equipped backpack/armour in browser
  const equipped = useMemo(() => DEBUG_EQUIPPED, []);

  const active = WEARABLES.find((w) => w.id === selected);

  const onSelect = (id: WearableSlotId) => {
    setSelected((prev) => (prev === id ? null : id));
  };

  return (
    <div className="wearables-panel">
      <div className="wearables-slots" role="list" aria-label="Wearables">
        {WEARABLES.map((item) => {
          const isSelected = selected === item.id;
          const isEquipped = !!equipped[item.id];

          return (
            <button
              key={item.id}
              type="button"
              role="listitem"
              className={`wearables-slot${isSelected ? ' wearables-slot-selected' : ''}${
                isEquipped ? ' wearables-slot-equipped' : ''
              }`}
              title={item.label}
              aria-label={item.label}
              aria-pressed={isSelected}
              onClick={() => onSelect(item.id)}
            >
              <span className="wearables-slot-icon">{item.icon}</span>
            </button>
          );
        })}
      </div>

      <div className="wearables-detail">
        {active?.storageSlots !== undefined ? (
          <StorageGrid
            slots={active.storageSlots}
            locked={!equipped[active.id]}
            label={active.label}
          />
        ) : (
          // Transparent region — scripted cam shows the ped through the NUI
          <div className="wearables-preview">
            {!selected && <span className="wearables-preview-hint">Select a wearable</span>}
            {selected && <span className="wearables-preview-hint">{active?.label}</span>}
          </div>
        )}
      </div>
    </div>
  );
};

export default WearablesPanel;
