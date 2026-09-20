import { createSlice, PayloadAction, createSelector } from '@reduxjs/toolkit';
import type { RootState } from '.';

export type ShopCartLine = {
  shopSlot: number;
  name: string;
  label: string;
  price: number;
  currency?: string;
  count: number;
  /** Max purchasable (shop stock); undefined = unlimited */
  maxCount?: number;
};

interface ShopCartState {
  shopId: string | null;
  lines: ShopCartLine[];
}

const initialState: ShopCartState = {
  shopId: null,
  lines: [],
};

const shopCartSlice = createSlice({
  name: 'shopCart',
  initialState,
  reducers: {
    /** Bind cart to the open shop; clears if the shop id changed */
    bindShopCart: (state, action: PayloadAction<string | null>) => {
      const id = action.payload;
      if (state.shopId !== id) {
        state.shopId = id;
        state.lines = [];
      }
    },
    addToCart: (
      state,
      action: PayloadAction<{
        shopSlot: number;
        name: string;
        label: string;
        price: number;
        currency?: string;
        maxCount?: number;
        count?: number;
      }>
    ) => {
      const { shopSlot, name, label, price, currency, maxCount } = action.payload;
      const addBy = Math.max(1, Math.floor(action.payload.count || 1));
      const existing = state.lines.find((line) => line.shopSlot === shopSlot);

      if (existing) {
        const next = existing.count + addBy;
        existing.count = maxCount !== undefined ? Math.min(next, maxCount) : Math.min(next, 99);
        existing.maxCount = maxCount;
        return;
      }

      const start = maxCount !== undefined ? Math.min(addBy, maxCount) : Math.min(addBy, 99);
      if (start < 1) return;

      state.lines.push({
        shopSlot,
        name,
        label,
        price,
        currency,
        count: start,
        maxCount,
      });
    },
    setCartQty: (state, action: PayloadAction<{ shopSlot: number; count: number }>) => {
      const line = state.lines.find((entry) => entry.shopSlot === action.payload.shopSlot);
      if (!line) return;

      const cap = line.maxCount !== undefined ? line.maxCount : 99;
      const next = Math.max(0, Math.min(Math.floor(action.payload.count), cap));

      if (next <= 0) {
        state.lines = state.lines.filter((entry) => entry.shopSlot !== action.payload.shopSlot);
        return;
      }

      line.count = next;
    },
    removeFromCart: (state, action: PayloadAction<number>) => {
      state.lines = state.lines.filter((line) => line.shopSlot !== action.payload);
    },
    clearCart: (state) => {
      state.lines = [];
    },
  },
});

export const { bindShopCart, addToCart, setCartQty, removeFromCart, clearCart } = shopCartSlice.actions;

export const selectShopCartLines = (state: RootState) => state.shopCart.lines;

/** Totals keyed by currency (money when unset) */
export const selectShopCartTotals = createSelector(selectShopCartLines, (lines) => {
  const totals: Record<string, number> = {};

  for (const line of lines) {
    const currency = line.currency || 'money';
    totals[currency] = (totals[currency] || 0) + line.price * line.count;
  }

  return totals;
});

export default shopCartSlice.reducer;
