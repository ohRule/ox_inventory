import React, { useEffect, useState } from 'react';
import { useDragLayer, useDrop } from 'react-dnd';
import { getItemUrl, HOTBAR_SLOTS, isSlotWithItem, resolveHotbarItem } from '../../helpers';
import useNuiEvent from '../../hooks/useNuiEvent';
import { Items } from '../../store/items';
import WeightBar from '../utils/WeightBar';
import { useAppSelector } from '../../store';
import { selectIsBusy, selectLeftInventory } from '../../store/inventory';
import { selectHotbarBinds } from '../../store/hotbar';
import SlideUp from '../utils/transitions/SlideUp';
import HotbarSlot from './HotbarSlot';
import { onUse } from '../../dnd/onUse';
import { onUnbindHotbar } from '../../dnd/onHotbar';
import { DragSource, InventoryType } from '../../typings';
import { Locale } from '../../store/locale';

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
  /** When true, hotbar is shown with the inventory and accepts bind drag/drop + 1-5 use. */
  interactive?: boolean;
}

const InventoryHotbar: React.FC<InventoryHotbarProps> = ({ interactive = false }) => {
  const [hotbarVisible, setHotbarVisible] = useState(false);
  const items = useAppSelector(selectLeftInventory).items;
  const binds = useAppSelector(selectHotbarBinds);
  const isBusy = useAppSelector(selectIsBusy);

  const [handle, setHandle] = useState<ReturnType<typeof setTimeout>>();
  useNuiEvent('toggleHotbar', () => {
    if (interactive) return;

    if (hotbarVisible) {
      setHotbarVisible(false);
    } else {
      if (handle) clearTimeout(handle);
      setHotbarVisible(true);
      setHandle(setTimeout(() => setHotbarVisible(false), 3000));
    }
  });

  useEffect(() => {
    if (!interactive) return;

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
  }, [interactive, binds, items, isBusy]);

  const slots = (
    <div
      className={`hotbar-container${interactive ? ' hotbar-container-interactive' : ''}`}
      style={interactive ? { pointerEvents: isBusy ? 'none' : 'auto' } : undefined}
    >
      <div className="hotbar-inner">
        {interactive && <HotbarUnbindZone />}
        <div className="hotbar-slots">
          {Array.from({ length: HOTBAR_SLOTS }, (_, i) => {
            const index = i + 1;
            const bind = binds[i] ?? null;
            const item = resolveHotbarItem(bind, items);

            if (interactive) {
              return <HotbarSlot key={`hotbar-${index}`} index={index} bind={bind} item={item} />;
            }

            return (
              <div
                className="hotbar-item-slot"
                style={{
                  backgroundImage: `url(${item?.name ? getItemUrl(item) : 'none'}`,
                }}
                key={`hotbar-${index}`}
              >
                {item && isSlotWithItem(item) ? (
                  <div className="item-slot-wrapper">
                    <div className="hotbar-slot-header-wrapper">
                      <div className="inventory-slot-number">{index}</div>
                      <div className="item-slot-info-wrapper">
                        <p>
                          {item.weight > 0
                            ? item.weight >= 1000
                              ? `${(item.weight / 1000).toLocaleString('en-us', {
                                  minimumFractionDigits: 2,
                                })}kg `
                              : `${item.weight.toLocaleString('en-us', {
                                  minimumFractionDigits: 0,
                                })}g `
                            : ''}
                        </p>
                        <p>{item.count ? item.count.toLocaleString('en-us') + `x` : ''}</p>
                      </div>
                    </div>
                    <div>
                      {item.durability !== undefined && <WeightBar percent={item.durability} durability />}
                      <div className="inventory-slot-label-box">
                        <div className="inventory-slot-label-text">
                          {item.metadata?.label ? item.metadata.label : Items[item.name]?.label || item.name}
                        </div>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="item-hotslot-header-wrapper">
                    <div className="inventory-slot-number">{index}</div>
                  </div>
                )}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );

  if (interactive) return slots;

  return <SlideUp in={hotbarVisible}>{slots}</SlideUp>;
};

export default InventoryHotbar;
