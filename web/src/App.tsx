import InventoryComponent from './components/inventory';
import useNuiEvent from './hooks/useNuiEvent';
import { Items } from './store/items';
import { Locale } from './store/locale';
import { setImagePath } from './store/imagepath';
import { setupInventory } from './store/inventory';
import { setupHotbar, HotbarPayload } from './store/hotbar';
import { setupQuickCraft, QuickCraftRecipe } from './store/quickcraft';
import { setupNavPanels, NavPanelsConfig } from './store/navPanels';
import { setupUiOptions } from './store/uiOptions';
import { Inventory } from './typings';
import { useAppDispatch } from './store';
import { debugData } from './utils/debugData';
import DragPreview from './components/utils/DragPreview';
import { fetchNui } from './utils/fetchNui';
import { useDragDropManager } from 'react-dnd';
import KeyPress from './components/utils/KeyPress';

const debugItem = (name: string, label: string, stack = true, usable = true) => ({
  name,
  label,
  stack,
  usable,
  close: false,
  count: 0,
});

debugData(
  [
    {
      action: 'init',
      data: {
        locale: {
          ui_use: 'Use',
          ui_give: 'Give',
          ui_close: 'Close',
          ui_unbind: 'Unbind',
          ui_cancel: 'Cancel',
          ui_confirm: 'Confirm',
          ui_amount: 'Amount',
          ui_split: 'Split',
          ui_drop: 'Drop',
          ui_usefulcontrols: 'Useful Controls',
          ui_rmb: 'Open item context menu',
          ui_shift_lmb: 'Fast move a stack of items into another inventory',
          ui_search_recipes: 'Search Recipes',
          ui_no_recipes: 'No recipes found',
          ui_shop: 'Shop',
          ui_cart_total: 'Total:',
          ui_checkout: 'Checkout',
          ui_cart_empty: 'Cart is empty',
          $: '$',
        },
        items: {
          iron: debugItem('iron', 'Iron'),
          copper: debugItem('copper', 'Copper'),
          water: debugItem('water', 'Water'),
          powersaw: debugItem('powersaw', 'Powersaw', false),
          backwoods: debugItem('backwoods', 'Backwoods', false),
          lockpick: debugItem('lockpick', 'Lockpick'),
          burger: debugItem('burger', 'Burger'),
          bandage: debugItem('bandage', 'Bandage'),
          clothe: debugItem('clothe', 'Cloth'),
          scrapmetal: debugItem('scrapmetal', 'Scrap Metal'),
        },
        imagepath: 'images',
        // Browser preview: enable all nav panels for local UI work
        navPanels: {
          craft: true,
          wearables: true,
          settings: true,
        } satisfies NavPanelsConfig,
        uiOptions: {
          showDurability: true,
        },
        quickCraft: [
          {
            id: 1,
            name: 'bandage',
            label: 'Bandages',
            category: 'medical',
            ingredients: { clothe: 5, water: 2 },
            duration: 5000,
            count: 10,
          },
          {
            id: 2,
            name: 'lockpick',
            label: 'Lockpick',
            category: 'tools',
            ingredients: { scrapmetal: 5 },
            duration: 3000,
            count: 1,
          },
          {
            id: 3,
            name: 'burger',
            label: 'Burger',
            category: 'medical',
            ingredients: { water: 1 },
            duration: 2000,
            count: 1,
          },
        ] satisfies QuickCraftRecipe[],
      },
    },
    {
      action: 'setupInventory',
      data: {
        leftInventory: {
          id: 'player',
          type: 'player',
          slots: 25,
          label: 'Player',
          weight: 3400,
          maxWeight: 50000,
          items: [
            {
              slot: 1,
              name: 'iron',
              weight: 3000,
              count: 5,
              metadata: { description: 'A stack of iron. Drag this to test the amount popup.' },
            },
            { slot: 2, name: 'powersaw', weight: 0, count: 1, metadata: { durability: 75 } },
            { slot: 3, name: 'copper', weight: 1200, count: 12, metadata: { type: 'Special' } },
            {
              slot: 4,
              name: 'water',
              weight: 1000,
              count: 10,
              metadata: { description: 'Bottled water' },
            },
            {
              slot: 5,
              name: 'backwoods',
              weight: 100,
              count: 1,
              metadata: {
                label: 'Russian Cream',
                imageurl: 'https://i.imgur.com/2xHhTTz.png',
              },
            },
            { slot: 6, name: 'burger', weight: 220, count: 8 },
            { slot: 7, name: 'clothe', weight: 5, count: 12 },
            { slot: 8, name: 'scrapmetal', weight: 500, count: 8 },
          ],
        },
        rightInventory: {
          id: 'general',
          type: 'shop',
          slots: 10,
          label: 'Shop',
          items: [
            { slot: 1, name: 'burger', weight: 220, count: 50, price: 10 },
            { slot: 2, name: 'water', weight: 100, count: 50, price: 11 },
            { slot: 3, name: 'bandage', weight: 50, count: 20, price: 25 },
            { slot: 4, name: 'lockpick', weight: 50, count: 5, price: 150 },
            { slot: 5, name: 'scrapmetal', weight: 500, count: 100, price: 5 },
          ],
        },
      },
    },
  ],
  100
);

const App: React.FC = () => {
  const dispatch = useAppDispatch();
  const manager = useDragDropManager();

  useNuiEvent<{
    locale: { [key: string]: string };
    items: typeof Items;
    leftInventory?: Inventory;
    imagepath: string;
    hotbarBinds?: HotbarPayload;
    quickCraft?: QuickCraftRecipe[];
    navPanels?: NavPanelsConfig;
    uiOptions?: { showDurability?: boolean };
  }>('init', ({ locale, items, leftInventory, imagepath, hotbarBinds, quickCraft, navPanels, uiOptions }) => {
    for (const name in locale) Locale[name] = locale[name];
    for (const name in items) Items[name] = items[name];

    setImagePath(imagepath);
    if (leftInventory) dispatch(setupInventory({ leftInventory }));
    dispatch(setupHotbar(hotbarBinds));
    dispatch(setupQuickCraft(quickCraft));
    dispatch(setupNavPanels(navPanels));
    dispatch(setupUiOptions(uiOptions));
  });

  fetchNui('uiLoaded', {});

  useNuiEvent('closeInventory', () => {
    manager.dispatch({ type: 'dnd-core/END_DRAG' });
  });

  return (
    <div className="app-wrapper">
      <InventoryComponent />
      <DragPreview />
      <KeyPress />
    </div>
  );
};

addEventListener('dragstart', function (event) {
  event.preventDefault();
});

export default App;
