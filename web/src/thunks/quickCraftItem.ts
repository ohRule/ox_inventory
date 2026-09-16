import { createAsyncThunk } from '@reduxjs/toolkit';
import { fetchNui } from '../utils/fetchNui';

/** Ask the game to craft a quick-craft recipe (separate from bench crafting). */
export const quickCraftItem = createAsyncThunk(
  'inventory/quickCraftItem',
  async (data: { recipeId: number; count: number }, { rejectWithValue }) => {
    try {
      const response = await fetchNui<boolean>('quickCraftItem', data);

      if (response === false) {
        return rejectWithValue(response);
      }

      return response;
    } catch {
      return rejectWithValue(false);
    }
  }
);
