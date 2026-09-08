import { store } from '../store';
import { Slot } from '../typings';
import { fetchNui } from '../utils/fetchNui';
import { promptMoveAmount } from '../helpers/amountPrompt';
import { isSlotWithItem } from '../helpers';

export const onGive = (item: Slot) => {
  const slot = store.getState().inventory.leftInventory.items[item.slot - 1];
  const max = isSlotWithItem(slot) ? slot.count : 1;

  const give = (count: number) => fetchNui('giveItem', { slot: item.slot, count });

  if (max > 1) {
    promptMoveAmount(max, max).then((count) => {
      if (count) give(count);
    });
    return;
  }

  give(max);
};
