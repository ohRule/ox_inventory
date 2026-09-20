export type Slot = {
  slot: number;
  name?: string;
  count?: number;
  weight?: number;
  metadata?: {
    [key: string]: any;
  };
  durability?: number;
};

export type SlotWithItem = Slot & {
  name: string;
  count: number;
  weight: number;
  durability?: number;
  price?: number;
  /** Trader: payout per unit when selling this item to the shop */
  buybackPrice?: number;
  currency?: string;
  ingredients?: { [key: string]: number };
  duration?: number;
  image?: string;
  grade?: number | number[];
  locked?: boolean;
  unlocked?: boolean;
  unlockItem?: { name: string; count?: number };
  unlockScrap?: number;
  researchScrap?: number;
  previousItem?: string;
};
