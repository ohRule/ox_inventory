import React, { useEffect, useState } from 'react';
import { useDragLayer, useDrop } from 'react-dnd';
import { HOTBAR_SLOTS, hotbarPlaceholder, resolveHotbarItem } from '../../helpers';
import useNuiEvent from '../../hooks/useNuiEvent';
import { useAppSelector } from '../../store';
import { selectIsBusy, selectLeftInventory } from '../../store/inventory';
import { selectHotbarBinds } from '../../store/hotbar';
import HotbarSlot from './HotbarSlot';
import { onUse } from '../../dnd/onUse';
import { onUnbindHotbar } from '../../dnd/onHotbar';
import { DragSource, InventoryType } from '../../typings';
import { Locale } from '../../store/locale';
import { fetchNui } from '../../utils/fetchNui';

const EyeIcon: React.FC<{ slashed?: boolean }> = ({ slashed = false }) => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
    {slashed ? (
      <>
        <path d="M9.88 9.88a3 3 0 1 0 4.24 4.24" />
        <path d="M10.73 5.08A10.43 10.43 0 0 1 12 5c7 0 10 7 10 7a13.16 13.16 0 0 1-1.67 2.68" />
        <path d="M6.61 6.61A13.53 13.53 0 0 0 2 12s3 7 10 7a9.74 9.74 0 0 0 5.39-1.61" />
        <line x1="2" y1="2" x2="22" y2="22" />
      </>
    ) : (
      <>
        <path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7z" />
        <circle cx="12" cy="12" r="3" />
      </>
    )}
  </svg>
);

/** Drop a hotbar bind here to remove the shortcut without moving the item. */
const HotbarUnbindZone: React.FC = () => {
  const isDraggingBind = useDragLayer(
    (monitor) => monitor.isDragging() && monitor.getItemType() === 'HOTBAR'
  );
  const [{ isOver }, drop] = useDrop<DragSource, void, { isOver: boolean }>(
    () => ({
      accept: 'HOTBAR',
      collect: (monitor) => ({
        isOver: monitor.isOver(),
      }),
      drop: (source) => {
        if (source.inventory === InventoryType.HOTBAR) onUnbindHotbar(source.item.slot);
      },
    }),
    []
  );

  return (
    <div
      ref={(el) => {
        drop(el);
      }}
      className={`hotbar-unbind-zone${isDraggingBind ? ' hotbar-unbind-zone-visible' : ''}${
        isOver ? ' hotbar-unbind-zone-active' : ''
      }`}
    >
      {Locale.ui_unbind || 'Unbind'}
    </div>
  );
};

interface InventoryHotbarProps {
  /** Inventory is open: enable bind drag/drop, unbind zone, and 1-N use. */
  inventoryOpen?: boolean;
}

const InventoryHotbar: React.FC<InventoryHotbarProps> = ({ inventoryOpen = false }) => {
  // HUD hotbar stays on unless the player hides it with the toggle / keybind
  const [hotbarVisible, setHotbarVisible] = useState(true);
  const items = useAppSelector(selectLeftInventory).items;
  const binds = useAppSelector(selectHotbarBinds);
  const isBusy = useAppSelector(selectIsBusy);

  useNuiEvent<{ hotbarHud?: boolean }>('init', (data) => {
    if (typeof data.hotbarHud === 'boolean') setHotbarVisible(data.hotbarHud);
  });

  useNuiEvent<boolean>('setHotbarHud', (visible) => setHotbarVisible(!!visible));

  const toggleHud = () => {
    const next = !hotbarVisible;
    setHotbarVisible(next);
    fetchNui('setHotbarHud', { visible: next });
  };

  useEffect(() => {
    if (!inventoryOpen) return;

    const onKeyDown = (event: KeyboardEvent) => {
      if (event.repeat || isBusy) return;

      const target = event.target as HTMLElement | null;
      if (target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA')) return;

      const index = Number(event.key);
      if (index < 1 || index > HOTBAR_SLOTS) return;

      const item = resolveHotbarItem(binds[index - 1], items);
      if (!item) return;

      event.preventDefault();
      onUse(item);
    };

    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [inventoryOpen, binds, items, isBusy]);

  return (
    <div
      className={`hotbar-container${inventoryOpen ? ' hotbar-container-interactive' : ''}`}
      style={inventoryOpen ? { pointerEvents: isBusy ? 'none' : 'auto' } : undefined}
    >
      <div className="hotbar-row">
        {/* Matches the eye button width so the slots stay centered when it appears */}
        {inventoryOpen && <div className="hotbar-toggle-spacer" aria-hidden="true" />}
        {(hotbarVisible || inventoryOpen) && (
          <div className="hotbar-inner">
            {inventoryOpen && <HotbarUnbindZone />}
            <div className="hotbar-slots">
              {Array.from({ length: HOTBAR_SLOTS }, (_, i) => {
                const index = i + 1;
                const bind = binds[i] ?? null;
                const liveItem = resolveHotbarItem(bind, items);
                const missing = !!bind && !liveItem;
                // Keep showing the bound item icon even when it's not in the inventory
                const item = liveItem ?? (missing ? hotbarPlaceholder(bind) : undefined);

                return (
                  <HotbarSlot
                    key={`hotbar-${index}`}
                    index={index}
                    bind={bind}
                    item={item}
                    missing={missing}
                    interactive={inventoryOpen}
                  />
                );
              })}
            </div>
          </div>
        )}
        {inventoryOpen && (
          <button
            type="button"
            className={`hotbar-toggle-btn${hotbarVisible ? ' hotbar-toggle-btn-on' : ''}`}
            onClick={(event) => {
              event.preventDefault();
              event.stopPropagation();
              toggleHud();
            }}
            title={
              hotbarVisible
                ? Locale.ui_hide_hotbar || 'Hide hotbar'
                : Locale.ui_show_hotbar || 'Show hotbar'
            }
          >
            <EyeIcon slashed={!hotbarVisible} />
          </button>
        )}
      </div>
    </div>
  );
};

export default InventoryHotbar;
