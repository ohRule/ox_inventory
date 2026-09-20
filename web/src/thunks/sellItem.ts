import { createAsyncThunk } from '@reduxjs/toolkit';
import { fetchNui } from '../utils/fetchNui';

export const sellItem = createAsyncThunk(
  'inventory/sellItem',
  async (
    data: {
      fromSlot: number;
      fromType: string;
      toSlot: number;
      toType: string;
      count: number;
    },
    { rejectWithValue }
  ) => {
    try {
      const response = await fetchNui<boolean>('sellItem', data);

      if (response === false) {
        return rejectWithValue(response);
      }
    } catch (error) {
      return rejectWithValue(false);
    }
  }
);
