import { createAsyncThunk } from '@reduxjs/toolkit';
import { fetchNui } from '../utils/fetchNui';
import type { BuyCartItem } from './buyCart';

export const sellCart = createAsyncThunk(
  'inventory/sellCart',
  async (data: { items: BuyCartItem[] }, { rejectWithValue }) => {
    try {
      const response = await fetchNui<boolean>('sellCart', data);

      if (response === false) {
        return rejectWithValue(response);
      }

      return response;
    } catch {
      return rejectWithValue(false);
    }
  }
);
