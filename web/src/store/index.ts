import { Action, configureStore, ThunkAction } from '@reduxjs/toolkit';
import { TypedUseSelectorHook, useDispatch, useSelector } from 'react-redux';
import inventoryReducer from './inventory';
import tooltipReducer from './tooltip';
import contextMenuReducer from './contextMenu';
import hotbarReducer from './hotbar';
import quickCraftReducer from './quickcraft';
import navPanelsReducer from './navPanels';
import uiOptionsReducer from './uiOptions';
import shopCartReducer from './shopCart';

export const store = configureStore({
  reducer: {
    inventory: inventoryReducer,
    tooltip: tooltipReducer,
    contextMenu: contextMenuReducer,
    hotbar: hotbarReducer,
    quickcraft: quickCraftReducer,
    navPanels: navPanelsReducer,
    uiOptions: uiOptionsReducer,
    shopCart: shopCartReducer,
  },
});

export type AppDispatch = typeof store.dispatch;
export type RootState = ReturnType<typeof store.getState>;
export type AppThunk<ReturnType = void> = ThunkAction<ReturnType, RootState, unknown, Action<string>>;

export const useAppDispatch = () => useDispatch<AppDispatch>();
export const useAppSelector: TypedUseSelectorHook<RootState> = useSelector;
