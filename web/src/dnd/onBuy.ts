import { isSlotWithItem } from '../helpers';
import { promptMoveAmount } from '../helpers/amountPrompt';
import { store } from '../store';
import { DragSource, DropTarget } from '../typings';
import { Items } from '../store/items';
import { buyItem } from '../thunks/buyItem';

export const onBuy = (source: DragSource, target: DropTarget) => {
  const { inventory: state } = store.getState();

  const sourceInventory = state.rightInventory;
  const targetInventory = state.leftInventory;

  const sourceSlot = sourceInventory.items[source.item.slot - 1];

  if (!isSlotWithItem(sourceSlot)) throw new Error(`Item ${sourceSlot.slot} name === undefined`);

  if (sourceSlot.count === 0) return;

  const sourceData = Items[sourceSlot.name];

  if (sourceData === undefined) return console.error(`Item ${sourceSlot.name} data undefined!`);

  const targetSlot = targetInventory.items[target.item.slot - 1];

  if (targetSlot === undefined) return console.error(`Target slot undefined`);

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
