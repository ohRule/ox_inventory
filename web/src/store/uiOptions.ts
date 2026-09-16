import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface UiOptionsState {
  /** Durability bars / checks (driven by inventory:durability convar) */
  showDurability: boolean;
}

const initialState: UiOptionsState = {
  showDurability: true,
};

const uiOptionsSlice = createSlice({
  name: 'uiOptions',
  initialState,
  reducers: {
    setupUiOptions: (state, action: PayloadAction<Partial<UiOptionsState> | undefined>) => {
      const next = action.payload ?? {};
      if (typeof next.showDurability === 'boolean') {
        state.showDurability = next.showDurability;
      }
    },
  },
});

export const { setupUiOptions } = uiOptionsSlice.actions;
export const selectShowDurability = (state: { uiOptions: UiOptionsState }) => state.uiOptions.showDurability;

export default uiOptionsSlice.reducer;
