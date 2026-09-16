import { createSlice, PayloadAction } from '@reduxjs/toolkit';

export type RightPanelMode = 'inventory' | 'craft' | 'wearables' | 'settings';

/** Optional middle-nav panels (inventory tab is implied when any of these are on) */
export type NavPanelId = Exclude<RightPanelMode, 'inventory'>;

export type NavPanelsConfig = Record<NavPanelId, boolean>;

interface NavPanelsState {
  panels: NavPanelsConfig;
}

const initialState: NavPanelsState = {
  // Defaults off until the server enables them via convars / init
  panels: {
    craft: false,
    wearables: false,
    settings: false,
  },
};

const navPanelsSlice = createSlice({
  name: 'navPanels',
  initialState,
  reducers: {
    setupNavPanels: (state, action: PayloadAction<Partial<NavPanelsConfig> | undefined>) => {
      const next = action.payload ?? {};
      state.panels = {
        craft: !!next.craft,
        wearables: !!next.wearables,
        settings: !!next.settings,
      };
    },
  },
});

export const { setupNavPanels } = navPanelsSlice.actions;
export const selectNavPanels = (state: { navPanels: NavPanelsState }) => state.navPanels.panels;
export const selectNavVisible = (state: { navPanels: NavPanelsState }) =>
  state.navPanels.panels.craft || state.navPanels.panels.wearables || state.navPanels.panels.settings;

export default navPanelsSlice.reducer;
