import { createAsyncThunk } from '@reduxjs/toolkit';
import { fetchNui } from '../utils/fetchNui';

export type BuyCartItem = {
  fromSlot: number;
  count: number;
};

export const buyCart = createAsyncThunk(
  'inventory/buyCart',
  async (data: { items: BuyCartItem[] }, { rejectWithValue }) => {
    try {
      const response = await fetchNui<boolean>('buyCart', data);

      if (response === false) {
        return rejectWithValue(response);
      }

      return response;
    } catch {
      return rejectWithValue(false);
    }
  }
);
