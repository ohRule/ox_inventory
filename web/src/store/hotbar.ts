import { createSlice, PayloadAction } from '@reduxjs/toolkit';
import { HOTBAR_SLOTS } from '../helpers/constants';
import type { RootState } from '.';

export type HotbarBind = {
  slot: number;
  name: string;
  serial?: string;
};

export type HotbarPayload = (HotbarBind | false | null)[] | Record<string, HotbarBind | false | null>;

type HotbarState = {
  binds: (HotbarBind | null)[];
};

const emptyBinds = (): (HotbarBind | null)[] => Array.from({ length: HOTBAR_SLOTS }, () => null);

const toBind = (entry: HotbarBind | false | null | undefined): HotbarBind | null =>
  entry && typeof entry === 'object' && entry.name ? entry : null;

const normalizeBinds = (payload?: HotbarPayload): (HotbarBind | null)[] => {
  const binds = emptyBinds();
  if (!payload) return binds;

  if (Array.isArray(payload)) {
    for (let i = 0; i < HOTBAR_SLOTS; i++) {
      binds[i] = toBind(payload[i]);
    }
    return binds;
  }

  for (let i = 1; i <= HOTBAR_SLOTS; i++) {
    binds[i - 1] = toBind(payload[i] ?? payload[String(i)]);
  }

  return binds;
};

const initialState: HotbarState = {
  binds: emptyBinds(),
};

export const hotbarSlice = createSlice({
  name: 'hotbar',
  initialState,
  reducers: {
    setupHotbar: (state, action: PayloadAction<HotbarPayload | undefined>) => {
      state.binds = normalizeBinds(action.payload);
    },
    bindHotbar: (state, action: PayloadAction<{ index: number; bind: HotbarBind }>) => {
      state.binds[action.payload.index - 1] = action.payload.bind;
    },
    unbindHotbar: (state, action: PayloadAction<number>) => {
      state.binds[action.payload - 1] = null;
    },
    swapHotbar: (state, action: PayloadAction<{ from: number; to: number }>) => {
      const from = action.payload.from - 1;
      const to = action.payload.to - 1;
      const previous = state.binds[from];
      state.binds[from] = state.binds[to];
      state.binds[to] = previous;
    },
  },
});

export const { setupHotbar, bindHotbar, unbindHotbar, swapHotbar } = hotbarSlice.actions;
export const selectHotbarBinds = (state: RootState) => state.hotbar.binds;

export default hotbarSlice.reducer;
