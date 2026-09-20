import { isGridShop, isSlotWithItem, shopSellPrice } from '../helpers';
import { promptMoveAmount } from '../helpers/amountPrompt';
import { store } from '../store';
import { DragSource, DropTarget } from '../typings';
import { Locale } from '../store/locale';
import { fetchNui } from '../utils/fetchNui';
import { sellItem } from '../thunks/sellItem';

/** Drag a player item onto a pawn/trader listing (or shift-click) to sell it. */
export const onSell = (source: DragSource, target?: DropTarget) => {
  const { inventory: state } = store.getState();
  const playerInventory = state.leftInventory;
  const shop = state.rightInventory;

  if (!isGridShop(shop.style)) return;

  const playerSlot = playerInventory.items[source.item.slot - 1];
  if (!isSlotWithItem(playerSlot)) return;

  const listing = target
    ? shop.items[target.item.slot - 1]
    : shop.items.find((entry) => entry.name === playerSlot.name && shopSellPrice(entry, shop.style) !== undefined);

  if (!listing || !isSlotWithItem(listing) || listing.name !== playerSlot.name || shopSellPrice(listing, shop.style) === undefined) {
    fetchNui('notify', { type: 'error', description: Locale.cannot_sell || "They don't buy that" });
    return;
  }

  const max = playerSlot.count || 1;

  promptMoveAmount(max, max).then((count) => {
    if (!count) return;

    store.dispatch(
      sellItem({
        fromSlot: playerSlot.slot,
        toSlot: listing.slot,
        fromType: playerInventory.type,
        toType: shop.type,
        count,
      })
    );
  });
};
