import { canStack, findAvailableSlot, getTargetInventory, isSlotWithItem } from '../helpers';
import { promptMoveAmount } from '../helpers/amountPrompt';
import { validateMove } from '../thunks/validateItems';
import { store } from '../store';
import { DragSource, DropTarget, InventoryType, Slot, SlotWithItem } from '../typings';
import { moveSlots, stackSlots, swapSlots } from '../store/inventory';
import { Items } from '../store/items';
import { Locale } from '../store/locale';

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

  const targetSlot = target
    ? targetInventory.items[target.item.slot - 1]
    : findAvailableSlot(sourceSlot, sourceData, targetInventory.items);

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
