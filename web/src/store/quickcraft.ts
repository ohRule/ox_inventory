import { createSlice, PayloadAction } from '@reduxjs/toolkit';

export type QuickCraftCategory = 'weapons' | 'ammo' | 'tools' | 'medical' | string;

export type QuickCraftRecipe = {
  id: number;
  name: string;
  label: string;
  category: QuickCraftCategory;
  ingredients: Record<string, number>;
  duration: number;
  count: number;
};

interface QuickCraftState {
  recipes: QuickCraftRecipe[];
}

const initialState: QuickCraftState = {
  recipes: [],
};

const quickCraftSlice = createSlice({
  name: 'quickcraft',
  initialState,
  reducers: {
    setupQuickCraft: (state, action: PayloadAction<QuickCraftRecipe[] | undefined>) => {
      state.recipes = action.payload ?? [];
    },
  },
});

export const { setupQuickCraft } = quickCraftSlice.actions;
export const selectQuickCraftRecipes = (state: { quickcraft: QuickCraftState }) => state.quickcraft.recipes;
export default quickCraftSlice.reducer;
