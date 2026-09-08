import { fetchNui } from '../utils/fetchNui';
import { store } from '../store';
import { bindHotbar, HotbarBind, swapHotbar, unbindHotbar } from '../store/hotbar';

/** Bind an inventory item to a hotbar key without moving the item. */
export const onBindHotbar = (index: number, bind: HotbarBind) => {
  store.dispatch(bindHotbar({ index, bind }));
  fetchNui('bindHotbar', { index, ...bind });
};

/** Remove a hotbar bind; the real item stays in the inventory. */
export const onUnbindHotbar = (index: number) => {
  store.dispatch(unbindHotbar(index));
  fetchNui('unbindHotbar', { index });
};

export const onSwapHotbar = (from: number, to: number) => {
  if (from === to) return;
  store.dispatch(swapHotbar({ from, to }));
  fetchNui('swapHotbar', { from, to });
};
