import React, { useRef } from 'react';
import { useDrag, useDrop } from 'react-dnd';
import { DragSource, InventoryType, SlotWithItem } from '../../typings';
import { getItemUrl, isSlotWithItem } from '../../helpers';
import { useAppDispatch, useAppSelector } from '../../store';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import WeightBar from '../utils/WeightBar';
import { onBindHotbar, onSwapHotbar, onUnbindHotbar } from '../../dnd/onHotbar';
import { HotbarBind } from '../../store/hotbar';
import { selectLeftInventory } from '../../store/inventory';

interface Props {
  index: number;
  bind: HotbarBind | null;
  item?: SlotWithItem;
  /** Bind drag/drop and tooltips only while inventory is open. */
  interactive?: boolean;
}

const HotbarSlot: React.FC<Props> = ({ index, bind, item, interactive = false }) => {
  const dispatch = useAppDispatch();
  const timerRef = useRef<number | null>(null);
  const leftItems = useAppSelector(selectLeftInventory).items;

  const [{ isDragging }, drag] = useDrag<DragSource, void, { isDragging: boolean }>(
    () => ({
      type: 'HOTBAR',
      collect: (monitor) => ({
        isDragging: monitor.isDragging(),
      }),
      item: () =>
        bind
          ? {
              inventory: InventoryType.HOTBAR,
              item: { name: bind.name, slot: index },
              image: item?.name ? `url(${getItemUrl(item) || 'none'}` : undefined,
            }
          : null,
      canDrag: () => interactive && !!bind,
    }),
    [bind, item, index, interactive]
  );

  const [{ isOver }, drop] = useDrop<DragSource, void, { isOver: boolean }>(
    () => ({
      accept: ['SLOT', 'HOTBAR'],
      collect: (monitor) => ({
        isOver: monitor.isOver(),
      }),
      canDrop: (source) =>
        interactive &&
        (source.inventory === InventoryType.PLAYER ||
          (source.inventory === InventoryType.HOTBAR && source.item.slot !== index)),
      drop: (source) => {
        if (!interactive) return;
        dispatch(closeTooltip());

        if (source.inventory === InventoryType.HOTBAR) {
          onSwapHotbar(source.item.slot, index);
          return;
        }

        if (source.inventory !== InventoryType.PLAYER || !source.item.name) return;

        const sourceItem = leftItems[source.item.slot - 1];
        onBindHotbar(index, {
          slot: source.item.slot,
          name: source.item.name,
          serial: sourceItem?.metadata?.serial,
        });
      },
    }),
    [index, leftItems, interactive]
  );

  const connectRef = (element: HTMLDivElement | null) => {
    if (!element) return;
    drag(drop(element));
  };

  const handleContext = (event: React.MouseEvent<HTMLDivElement>) => {
    event.preventDefault();
    if (!interactive || !bind) return;
    onUnbindHotbar(index);
  };

  const handleClick = (event: React.MouseEvent<HTMLDivElement>) => {
    if (!interactive) return;
    dispatch(closeTooltip());
    if (timerRef.current) clearTimeout(timerRef.current);
  };

  return (
    <div
      ref={connectRef}
      onContextMenu={handleContext}
      onClick={handleClick}
      className="hotbar-item-slot"
      style={{
        opacity: isDragging ? 0.4 : 1.0,
        backgroundImage: `url(${item?.name ? getItemUrl(item) : 'none'}`,
        border: isOver ? '1px dashed rgba(255,255,255,0.4)' : '',
      }}
    >
      {!item && (
        <div className="item-hotslot-header-wrapper">
          <div className="inventory-slot-number">{index}</div>
        </div>
      )}
      {item && isSlotWithItem(item) && (
        <div
          className="item-slot-wrapper"
          onMouseEnter={() => {
            if (!interactive) return;
            timerRef.current = window.setTimeout(() => {
              dispatch(openTooltip({ item, inventoryType: InventoryType.PLAYER }));
            }, 150) as unknown as number;
          }}
          onMouseLeave={() => {
            dispatch(closeTooltip());
            if (timerRef.current) {
              clearTimeout(timerRef.current);
              timerRef.current = null;
            }
          }}
        >
          <div className="hotbar-slot-header-wrapper">
            <div className="inventory-slot-number">{index}</div>
          </div>
          <div>
            {item.durability !== undefined && <WeightBar percent={item.durability} durability />}
          </div>
        </div>
      )}
    </div>
  );
};

export default HotbarSlot;
