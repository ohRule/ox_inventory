import React, { useCallback, useEffect, useRef, useState } from 'react';
import { DragSource, Inventory, InventoryType, Slot, SlotWithItem } from '../../typings';
import { useDrag, useDragDropManager, useDrop } from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import WeightBar from '../utils/WeightBar';
import { onDrop } from '../../dnd/onDrop';
import { onSell } from '../../dnd/onSell';
import { onBuy } from '../../dnd/onBuy';
import { canCraftItem, canPurchaseItem, furnaceAllows, getItemUrl, isGridShop, isSlotWithItem, shopSellPrice } from '../../helpers';
import { Locale } from '../../store/locale';
import { onCraft } from '../../dnd/onCraft';
import useNuiEvent from '../../hooks/useNuiEvent';
import { ItemsPayload } from '../../reducers/refreshSlots';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import { openContextMenu } from '../../store/contextMenu';
import { useMergeRefs } from '@floating-ui/react';
import { onUnbindHotbar } from '../../dnd/onHotbar';
import { selectShowDurability } from '../../store/uiOptions';

const BUY_PRICE_COLOR = '#2ECC71';
const SELL_PRICE_COLOR = '#E8C547';

const ShopPrice: React.FC<{ amount: number; currency?: string; color: string }> = ({ amount, currency, color }) => {
  if (currency && currency !== 'money' && currency !== 'black_money') {
    return (
      <div className="item-slot-currency-wrapper">
        <img
          src={getItemUrl(currency) || 'none'}
          alt=""
          style={{
            imageRendering: '-webkit-optimize-contrast',
            height: 'auto',
            width: '2vh',
            backfaceVisibility: 'hidden',
            transform: 'translateZ(0)',
          }}
        />
        <p>{amount.toLocaleString('en-us')}</p>
      </div>
    );
  }

  if (amount <= 0) return null;

  return (
    <div className="item-slot-price-wrapper" style={{ color }}>
      <p>
        {Locale.$ || '$'}
        {amount.toLocaleString('en-us')}
      </p>
    </div>
  );
};

interface SlotProps {
  inventoryId: Inventory['id'];
  inventoryType: Inventory['type'];
  inventoryGroups: Inventory['groups'];
  item: Slot;
  // Recycler output (and similar) reject incoming drops
  disableDrop?: boolean;
  // Item currently being processed cannot be moved
  locked?: boolean;
  highlighted?: boolean;
  searching?: boolean;
}

const InventorySlot: React.ForwardRefRenderFunction<HTMLDivElement, SlotProps> = (
  { item, inventoryId, inventoryType, inventoryGroups, disableDrop, locked, highlighted, searching },
  ref
) => {
  const manager = useDragDropManager();
  const dispatch = useAppDispatch();
  const timerRef = useRef<number | null>(null);
  const shopStyle = useAppSelector((state) => state.inventory.rightInventory.style);
  const gridShop = isGridShop(shopStyle);
  const isTrader = shopStyle === 'trader';
  const isPlaceholder = !!item.metadata?.placeholder;
  const showDurability = useAppSelector(selectShowDurability);
  const furnaceInv = useAppSelector((state) =>
    inventoryType === InventoryType.FURNACE ? state.inventory.rightInventory : undefined
  );
  const [justRevealed, setJustRevealed] = useState(false);
  const hadItem = useRef(!!item.name);

  useEffect(() => {
    if (item.name && !hadItem.current) {
      setJustRevealed(true);
      const timeout = window.setTimeout(() => setJustRevealed(false), 450);
      hadItem.current = true;
      return () => window.clearTimeout(timeout);
    }
    hadItem.current = !!item.name;
  }, [item.name]);

  const canDrag = useCallback(() => {
    if (inventoryType === InventoryType.SHOP) {
      // Trader listings can be dragged onto the player grid to buy
      if (!isTrader || isPlaceholder) return false;
      if (locked || searching) return false;
      return canPurchaseItem(item, { type: inventoryType, groups: inventoryGroups });
    }
    if (locked || searching) return false;
    return canPurchaseItem(item, { type: inventoryType, groups: inventoryGroups }) && canCraftItem(item, inventoryType);
  }, [item, inventoryType, inventoryGroups, locked, searching, isTrader, isPlaceholder]);

  const [{ isDragging }, drag] = useDrag<DragSource, void, { isDragging: boolean }>(
    () => ({
      type: 'SLOT',
      collect: (monitor) => ({
        isDragging: monitor.isDragging(),
      }),
      item: () =>
        isSlotWithItem(item, inventoryType !== InventoryType.SHOP)
          ? {
              inventory: inventoryType,
              item: {
                name: item.name,
                slot: item.slot,
              },
              image: item?.name && `url(${getItemUrl(item) || 'none'}`,
            }
          : null,
      canDrag,
    }),
    [inventoryType, item, canDrag]
  );

  const [{ isOver }, drop] = useDrop<DragSource, void, { isOver: boolean }>(
    () => ({
      accept: ['SLOT', 'HOTBAR'],
      collect: (monitor) => ({
        isOver: monitor.isOver(),
      }),
      drop: (source) => {
        dispatch(closeTooltip());
        // Dropping a hotbar bind onto the inventory only removes the shortcut
        if (source.inventory === InventoryType.HOTBAR) {
          onUnbindHotbar(source.item.slot);
          return;
        }
        switch (source.inventory) {
          case InventoryType.CRAFTING:
            onCraft(source, { inventory: inventoryType, item: { slot: item.slot } });
            break;
          case InventoryType.SHOP:
            onBuy(source, { inventory: inventoryType, item: { slot: item.slot } });
            break;
          default:
            if (inventoryType === InventoryType.SHOP && gridShop) {
              onSell(source, { inventory: inventoryType, item: { slot: item.slot } });
            } else {
              onDrop(source, { inventory: inventoryType, item: { slot: item.slot } });
            }
            break;
        }
      },
      canDrop: (source) => {
        if (source.inventory === InventoryType.HOTBAR) return true;
        if (source.inventory === InventoryType.SHOP) {
          return inventoryType === InventoryType.PLAYER && isTrader;
        }
        if (disableDrop || locked || searching) return false;
        // Ore tray vs fuel tray — each only accepts its own items.
        if (inventoryType === InventoryType.FURNACE) {
          if (source.inventory === InventoryType.FURNACE && source.item.slot === item.slot) return false;
          return !!furnaceInv && furnaceAllows(furnaceInv, item.slot, source.item.name);
        }
        if (inventoryType === InventoryType.SHOP && gridShop) {
          return (
            source.inventory === InventoryType.PLAYER &&
            isSlotWithItem(item) &&
            source.item.name === item.name &&
            shopSellPrice(item, shopStyle) !== undefined
          );
        }
        return (
          (source.item.slot !== item.slot || source.inventory !== inventoryType) &&
          inventoryType !== InventoryType.SHOP &&
          inventoryType !== InventoryType.CRAFTING &&
          inventoryType !== InventoryType.LOOTPROP
        );
      },
    }),
    [inventoryType, item, disableDrop, locked, searching, gridShop, isTrader, shopStyle, furnaceInv]
  );

  useNuiEvent('refreshSlots', (data: { items?: ItemsPayload | ItemsPayload[] }) => {
    if (!isDragging && !data.items) return;
    if (!Array.isArray(data.items)) return;

    const itemSlot = data.items.find(
      (dataItem) => dataItem.item.slot === item.slot && dataItem.inventory === inventoryId
    );

    if (!itemSlot) return;

    manager.dispatch({ type: 'dnd-core/END_DRAG' });
  });

  const connectRef = (element: HTMLDivElement | null) => {
    if (!element) return;
    drag(drop(element));
  };

  const handleContext = (event: React.MouseEvent<HTMLDivElement>) => {
    event.preventDefault();
    if (inventoryType !== 'player' || !isSlotWithItem(item)) return;

    dispatch(openContextMenu({ item, coords: { x: event.clientX, y: event.clientY } }));
  };

  const handleClick = (event: React.MouseEvent<HTMLDivElement>) => {
    dispatch(closeTooltip());
    if (timerRef.current) clearTimeout(timerRef.current);
    if (event.shiftKey && isSlotWithItem(item)) {
      if (inventoryType === 'shop' && isTrader && !isPlaceholder) {
        onBuy({ item: { name: item.name, slot: item.slot }, inventory: InventoryType.SHOP });
        return;
      }
      if (inventoryType !== 'shop' && inventoryType !== 'crafting') {
        onDrop({ item: item, inventory: inventoryType });
      }
    }
  };

  const refs = useMergeRefs([connectRef, ref]);

  return (
    <div
      ref={refs}
      onContextMenu={handleContext}
      onClick={handleClick}
      className={`inventory-slot${highlighted ? ' inventory-slot-busy' : ''}${searching ? ' inventory-slot-searching' : ''}${justRevealed ? ' inventory-slot-reveal' : ''}`}
      style={{
        filter:
          !isPlaceholder &&
          (!canPurchaseItem(item, { type: inventoryType, groups: inventoryGroups }) ||
            !canCraftItem(item, inventoryType))
            ? 'brightness(80%) grayscale(100%)'
            : undefined,
        opacity: isDragging ? 0.4 : 1.0,
        backgroundImage: `url(${item?.name ? getItemUrl(item as SlotWithItem) : 'none'}`,
        border: isOver ? '1px dashed rgba(var(--inv-highlight), 0.75)' : undefined,
      }}
    >
      {isSlotWithItem(item) && (
        <div
          className="item-slot-wrapper"
          onMouseEnter={() => {
            timerRef.current = window.setTimeout(() => {
              dispatch(openTooltip({ item, inventoryType }));
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
          {(() => {
            const sellPrice = shopSellPrice(item, shopStyle);
            const showBuy =
              inventoryType === 'shop' && !isPlaceholder && item.price !== undefined && shopStyle !== 'pawn';
            const showSell = inventoryType === 'shop' && sellPrice !== undefined;
            const showPrices = showBuy || showSell || (showDurability && inventoryType !== 'shop' && item.durability !== undefined);

            if (!showPrices) return null;

            return (
              <div>
                {showDurability && inventoryType !== 'shop' && item.durability !== undefined && (
                  <WeightBar percent={item.durability} durability />
                )}
                {showBuy && (
                  <ShopPrice
                    amount={item.price ?? 0}
                    currency={item.currency}
                    color={item.currency === 'black_money' ? '#E74C3C' : BUY_PRICE_COLOR}
                  />
                )}
                {showSell && sellPrice !== undefined && (
                  <ShopPrice amount={sellPrice} currency={item.currency} color={showBuy ? SELL_PRICE_COLOR : BUY_PRICE_COLOR} />
                )}
              </div>
            );
          })()}
          {/* Quantity bottom-left */}
          <p className="item-slot-count">{item.count ? item.count.toLocaleString('en-us') + `x` : ''}</p>
        </div>
      )}
    </div>
  );
};

export default React.memo(React.forwardRef(InventorySlot));
