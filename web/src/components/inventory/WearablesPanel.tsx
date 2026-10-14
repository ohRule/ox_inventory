import React, { useEffect, useMemo, useState } from 'react';
import { useAppSelector } from '../../store';
import { selectLeftInventory, selectRightInventory } from '../../store/inventory';
import { InventoryType } from '../../typings';
import InventorySlot from './InventorySlot';
import { fetchNui } from '../../utils/fetchNui';
import { getTotalWeight } from '../../helpers';
import { Items } from '../../store/items';

export type WearableSlotId = 'mask' | 'watch' | 'backpack' | 'armour' | 'holster';

type WearableDef = {
  id: WearableSlotId;
  label: string;
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
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M8 6V5a4 4 0 0 1 8 0v1h2a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2zm2 0h4V5a2 2 0 0 0-4 0v1zm-3 4v3h4v-1.5h2V13h4V10H7zm0 5v4h10v-4h-4v1.5h-2V15H7z" />
      </svg>
    ),
  },
  {
    id: 'armour',
    label: 'Armour',
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

// A worn container (a bag) shows its own slots here. It's opened as the right-hand
// inventory, as using it from the pockets would, so dragging in and out works as usual.
const BagStorage: React.FC<{ label: string; containerId: string }> = ({ label, containerId }) => {
  const rightInventory = useAppSelector(selectRightInventory);
  const open = rightInventory.type === InventoryType.CONTAINER && rightInventory.id === containerId;
  const weight = useMemo(
    () => (open && rightInventory.maxWeight !== undefined ? Math.floor(getTotalWeight(rightInventory.items) * 1000) / 1000 : 0),
    [open, rightInventory.maxWeight, rightInventory.items]
  );

  return (
    <div className="wearables-storage">
      <p className="wearables-storage-label">
        {label}
        {open && rightInventory.maxWeight !== undefined && ` · ${weight / 1000}/${rightInventory.maxWeight / 1000}kg`}
      </p>
      <div className="wearables-storage-grid">
        {open &&
          rightInventory.items.map((item) => (
            <InventorySlot
              key={`${rightInventory.id}-${item.slot}`}
              item={item}
              inventoryId={rightInventory.id}
              inventoryType={rightInventory.type}
              inventoryGroups={rightInventory.groups}
            />
          ))}
      </div>
    </div>
  );
};

const WearablesPanel: React.FC = () => {
  const inventory = useAppSelector(selectLeftInventory);
  const rightInventory = useAppSelector(selectRightInventory);
  const [selected, setSelected] = useState<WearableSlotId | null>(null);
  const bagSlots = inventory.bagSlots ?? inventory.slots;
  const ids = inventory.wearableIds || WEARABLES.map((w) => w.id);

  const selectedItem = selected
    ? inventory.items[bagSlots + ids.indexOf(selected)]
    : undefined;
  const selectedBag: string | undefined = selectedItem?.name ? selectedItem.metadata?.container : undefined;
  // Only a worn container opens the storage pane; hide the ped while that pane is up
  const showStorage = !!selectedBag;

  useEffect(() => {
    // Unequipping the selected piece clears selection
    if (selected && !selectedBag) {
      setSelected(null);
    }
  }, [selected, selectedBag]);

  useEffect(() => {
    fetchNui('setWearablesPedVisible', { visible: !showStorage });
  }, [showStorage]);

  // Restore ped when leaving the wearables panel
  useEffect(() => {
    return () => {
      fetchNui('setWearablesPedVisible', { visible: true });
    };
  }, []);

  return (
    <div className="wearables-panel">
      <div className="wearables-slots" role="list" aria-label="Wearables">
        {WEARABLES.map((def, index) => {
          const slot = bagSlots + index + 1;
          const item = inventory.items[slot - 1] || { slot };
          const bag: string | undefined = item.name ? item.metadata?.container : undefined;
          const canSelect = !!bag;
          const isSelected = canSelect && selected === def.id;
          const isEquipped = !!item.name;

          return (
            <div
              key={def.id}
              role="listitem"
              className={`wearables-slot${isSelected ? ' wearables-slot-selected' : ''}${
                isEquipped ? ' wearables-slot-equipped' : ''
              }${canSelect ? '' : ' wearables-slot-static'}`}
              title={def.label}
              onClick={
                canSelect
                  ? () => {
                      if (selected === def.id) return setSelected(null);
                      setSelected(def.id);
                      // Using it again while it's open would shut the whole inventory
                      const open = rightInventory.type === InventoryType.CONTAINER && rightInventory.id === bag;
                      if (!open) fetchNui('useItem', slot);
                    }
                  : undefined
              }
            >
              {!item.name && <span className="wearables-slot-placeholder">{def.icon}</span>}
              <InventorySlot
                item={item}
                inventoryId={inventory.id}
                inventoryType={InventoryType.PLAYER}
                inventoryGroups={inventory.groups}
              />
            </div>
          );
        })}
      </div>

      <div className="wearables-detail">
        {selectedBag ? (
          <BagStorage
            label={selectedItem?.metadata?.label || (selectedItem?.name && Items[selectedItem.name]?.label) || ''}
            containerId={selectedBag}
          />
        ) : (
          <div className="wearables-preview" />
        )}
      </div>
    </div>
  );
};

export default WearablesPanel;
