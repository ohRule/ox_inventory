import { canStack, findAvailableSlot, furnaceAllows, furnaceInputRange, getTargetInventory, isSlotWithItem } from '../helpers';
import { promptMoveAmount } from '../helpers/amountPrompt';
import { validateMove } from '../thunks/validateItems';
import { store } from '../store';
import { DragSource, DropTarget, InventoryType, Slot, SlotWithItem } from '../typings';
import { moveSlots, stackSlots, swapSlots } from '../store/inventory';
import { Items } from '../store/items';
import { Locale } from '../store/locale';
import { onSell } from './onSell';

const commitDrop = (
  sourceSlot: SlotWithItem,
  targetSlot: Slot,
  sourceInventoryType: string,
  targetInventoryType: string,
  count: number,
  canStackOnTarget: boolean
) => {
  const data = {
    fromSlot: sourceSlot,
    toSlot: targetSlot,
    fromType: sourceInventoryType,
    toType: targetInventoryType,
    count,
  };

  store.dispatch(
    validateMove({
      ...data,
      fromSlot: sourceSlot.slot,
      toSlot: targetSlot.slot,
    })
  );

  isSlotWithItem(targetSlot, true)
    ? canStackOnTarget
      ? store.dispatch(
          stackSlots({
            ...data,
            toSlot: targetSlot,
          })
        )
      : store.dispatch(
          swapSlots({
            ...data,
            toSlot: targetSlot,
          })
        )
    : store.dispatch(moveSlots(data));
};

export const onDrop = (source: DragSource, target?: DropTarget) => {
  const { inventory: state } = store.getState();

  const { sourceInventory, targetInventory } = getTargetInventory(state, source.inventory, target?.inventory);

  const sourceSlot = sourceInventory.items[source.item.slot - 1] as SlotWithItem;

  const sourceData = Items[sourceSlot.name];

  if (sourceData === undefined) return console.error(`${sourceSlot.name} item data undefined!`);

  // If dragging from container slot
  if (sourceSlot.metadata?.container !== undefined) {
    // Prevent storing container in container
    if (targetInventory.type === InventoryType.CONTAINER)
      return console.log(`Cannot store container ${sourceSlot.name} inside another container`);

    // Prevent dragging of container slot when opened
    if (state.rightInventory.id === sourceSlot.metadata.container)
      return console.log(`Cannot move container ${sourceSlot.name} when opened`);
  }

  const isFurnace = targetInventory.type === InventoryType.FURNACE;
  const inputLimit = targetInventory.type === InventoryType.RECYCLER ? targetInventory.inputSlots : undefined;

  // Shift-click into recycler input, or the matching furnace tray (ore vs fuel).
  let searchItems = targetInventory.items;
  if (!target && inputLimit) {
    searchItems = targetInventory.items.filter((slot) => slot.slot <= inputLimit);
  } else if (!target && isFurnace) {
    const range = furnaceInputRange(targetInventory, sourceSlot.name);
    if (!range) return;
    searchItems = targetInventory.items.filter((slot) => slot.slot >= range[0] && slot.slot <= range[1]);
  }

  if (target && inputLimit && target.item.slot > inputLimit) return;

  // Loot props are take-only
  if (targetInventory.type === InventoryType.LOOTPROP && sourceInventory.type !== InventoryType.LOOTPROP) return;

  if (isFurnace && target && !furnaceAllows(targetInventory, target.item.slot, sourceSlot.name)) return;

  // Pawn/trader: drag a matching player item onto the listing to sell it
  if (sourceInventory.type === InventoryType.PLAYER && targetInventory.type === InventoryType.SHOP && (targetInventory.style === 'pawn' || targetInventory.style === 'trader')) {
    onSell(source, target);
    return;
  }

  const targetSlot = target
    ? targetInventory.items[target.item.slot - 1]
    : findAvailableSlot(sourceSlot, sourceData, searchItems);

  if (targetSlot === undefined) return console.error('Target slot undefined!');

  // If dropping on container slot when opened
  if (targetSlot.metadata?.container !== undefined && state.rightInventory.id === targetSlot.metadata.container)
    return console.log(`Cannot swap item ${sourceSlot.name} with container ${targetSlot.name} when opened`);

  const canStackOnTarget = !!(sourceData.stack && canStack(sourceSlot, targetSlot));
  const isSwap = isSlotWithItem(targetSlot, true) && !canStackOnTarget;

  const finish = (count: number) =>
    commitDrop(sourceSlot, targetSlot, sourceInventory.type, targetInventory.type, count, canStackOnTarget);

  // Rearranging inside the same inventory always moves the full stack.
  // Amount is only asked when transferring to another inventory.
  if (!isSwap && sourceSlot.count > 1 && sourceInventory.id !== targetInventory.id) {
    // Research table takes a single item, like Rust.
    if (targetInventory.type === InventoryType.RESEARCH) {
      finish(1);
      return;
    }
    promptMoveAmount(sourceSlot.count, sourceSlot.count).then((count) => {
      if (count) finish(count);
    });
    return;
  }

  finish(sourceSlot.count);
};

/** Split part of a player stack into the first empty inventory slot. */
export const onSplit = (item: SlotWithItem) => {
  const { inventory: state } = store.getState();
  const sourceInventory = state.leftInventory;
  const sourceSlot = sourceInventory.items[item.slot - 1] as SlotWithItem | undefined;

  if (!sourceSlot?.name || sourceSlot.count <= 1) return;

  const emptySlot = sourceInventory.items.find((slot) => slot.name === undefined);
  if (!emptySlot) return;

  const sourceData = Items[sourceSlot.name];
  if (sourceData === undefined) return;

  const max = sourceSlot.count - 1;
  const initial = Math.max(1, Math.floor(sourceSlot.count / 2));

  promptMoveAmount(max, initial, { slider: true, title: Locale.ui_split || 'Split' }).then((count) => {
    if (!count) return;
    commitDrop(sourceSlot, emptySlot, sourceInventory.type, sourceInventory.type, count, false);
  });
};
