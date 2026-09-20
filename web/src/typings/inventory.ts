import { Slot } from './slot';

export type RecyclerProcess = {
  id: number;
  slot: number;
  name: string;
  label: string;
  duration: number;
  remaining: number;
  blocked?: boolean;
  needFuel?: boolean;
};

export enum InventoryType {
  PLAYER = 'player',
  SHOP = 'shop',
  CONTAINER = 'container',
  CRAFTING = 'crafting',
  HOTBAR = 'hotbar',
  RECYCLER = 'recycler',
  LOOTPROP = 'lootprop',
  RESEARCH = 'research',
  FURNACE = 'furnace',
}

export type ResearchRecipe = {
  scrap: number;
  unlocked: boolean;
};

export type Inventory = {
  id: string;
  type: string;
  slots: number;
  items: Slot[];
  maxWeight?: number;
  label?: string;
  groups?: Record<string, number>;
  style?: 'shop' | 'pawn' | 'trader';
  inputSlots?: number;
  running?: boolean;
  process?: RecyclerProcess | null;
  unlockedSlots?: Record<number, boolean>;
  techTree?: boolean;
  researchTable?: boolean;
  unlockScrapItem?: string;
  researchRecipes?: Record<string, ResearchRecipe>;
  benchId?: string;
  treeRootSlots?: number[];
  treeChildren?: Record<number, number[]>;
  index?: number;
  /** Furnace: ore tray size (slots 1..oreSlots) */
  oreSlots?: number;
  /** Furnace: fuel tray size (slots after ore) */
  fuelSlots?: number;
  acceptOre?: Record<string, boolean>;
  acceptFuel?: Record<string, boolean>;
};
