import { findAvailableSlot, isSlotWithItem } from '../helpers';
import { promptMoveAmount } from '../helpers/amountPrompt';
import { store } from '../store';
import { DragSource, DropTarget } from '../typings';
import { Items } from '../store/items';
import { buyItem } from '../thunks/buyItem';

/** Drag a trader listing onto a player slot (or shift-click) to buy it. */
export const onBuy = (source: DragSource, target?: DropTarget) => {
  const { inventory: state } = store.getState();

  const sourceInventory = state.rightInventory;
  const targetInventory = state.leftInventory;

  const sourceSlot = sourceInventory.items[source.item.slot - 1];

  if (!isSlotWithItem(sourceSlot) || sourceSlot.metadata?.placeholder) return;
  if (sourceSlot.count === 0) return;

  const sourceData = Items[sourceSlot.name];
  if (sourceData === undefined) return console.error(`Item ${sourceSlot.name} data undefined!`);

  const targetSlot = target
    ? targetInventory.items[target.item.slot - 1]
    : targetInventory.items.find((slot) => slot.name === undefined) ||
      findAvailableSlot(sourceSlot, sourceData, targetInventory.items);

  if (targetSlot === undefined) return console.error('Target slot undefined');

  const max = sourceSlot.count || 99;

  promptMoveAmount(max, 1).then((count) => {
    if (!count) return;

    store.dispatch(
      buyItem({
        fromSlot: sourceSlot.slot,
        toSlot: targetSlot.slot,
        fromType: sourceInventory.type,
        toType: targetInventory.type,
        count,
      })
    );
  });
};
