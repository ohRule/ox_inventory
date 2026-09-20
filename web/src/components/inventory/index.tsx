import React, { useEffect, useState } from 'react';
import useNuiEvent from '../../hooks/useNuiEvent';
import InventoryHotbar from './InventoryHotbar';
import { useAppDispatch, useAppSelector } from '../../store';
import { refreshSlots, setAdditionalMetadata, setupInventory, unlockLootSlot } from '../../store/inventory';
import { useExitListener } from '../../hooks/useExitListener';
import type { Inventory as InventoryProps } from '../../typings';
import RightInventory from './RightInventory';
import LeftInventory from './LeftInventory';
import InventoryNav, { RightPanelMode } from './InventoryNav';
import QuickCraftPanel from './quickcraft/QuickCraftPanel';
import WearablesPanel from './WearablesPanel';
import SettingsPanel from './SettingsPanel';
import Tooltip from '../utils/Tooltip';
import { closeTooltip } from '../../store/tooltip';
import InventoryContext from './InventoryContext';
import { closeContextMenu } from '../../store/contextMenu';
import Fade from '../utils/transitions/Fade';
import { setupHotbar, HotbarPayload } from '../../store/hotbar';
import { setupQuickCraft, QuickCraftRecipe } from '../../store/quickcraft';
import { selectNavPanels, setupNavPanels } from '../../store/navPanels';
import AmountDialog from './AmountDialog';
import { cancelAmountPrompt } from '../../helpers/amountPrompt';
import { fetchNui } from '../../utils/fetchNui';
import { clearCart } from '../../store/shopCart';

const Inventory: React.FC = () => {
  const [inventoryVisible, setInventoryVisible] = useState(false);
  const [rightPanelMode, setRightPanelMode] = useState<RightPanelMode>('inventory');
  const dispatch = useAppDispatch();
  const navPanels = useAppSelector(selectNavPanels);

  const changeRightPanelMode = (mode: RightPanelMode) => {
    // Ignore disabled optional panels
    if (mode !== 'inventory' && !navPanels[mode]) return;

    setRightPanelMode(mode);
    // Client starts/stops the wearables pause-menu ped from this
    fetchNui('setRightPanelMode', { mode });
  };

  // If the active panel is turned off, fall back to the right inventory grid
  useEffect(() => {
    if (rightPanelMode !== 'inventory' && !navPanels[rightPanelMode]) {
      changeRightPanelMode('inventory');
    }
  }, [navPanels, rightPanelMode]);

  useNuiEvent<boolean>('setInventoryVisible', setInventoryVisible);
  useNuiEvent<false>('closeInventory', () => {
    setInventoryVisible(false);
    setRightPanelMode('inventory');
    fetchNui('setRightPanelMode', { mode: 'inventory' });
    dispatch(closeContextMenu());
    dispatch(closeTooltip());
    dispatch(clearCart());
    cancelAmountPrompt();
  });
  useExitListener(setInventoryVisible);

  useNuiEvent<{
    leftInventory?: InventoryProps;
    rightInventory?: InventoryProps;
  }>('setupInventory', (data) => {
    dispatch(setupInventory(data));
    // External inventories (stash/shop/bench) always show on the right grid
    if (data.rightInventory) changeRightPanelMode('inventory');
    !inventoryVisible && setInventoryVisible(true);
  });

  useNuiEvent('refreshSlots', (data) => dispatch(refreshSlots(data)));

  useNuiEvent<{ slot: number }>('lootSearch', (data) => {
    if (data?.slot) dispatch(unlockLootSlot(data.slot));
  });

  useNuiEvent('setupHotbar', (data: HotbarPayload) => {
    dispatch(setupHotbar(data));
  });

  useNuiEvent('setupQuickCraft', (data: QuickCraftRecipe[]) => {
    dispatch(setupQuickCraft(data));
  });

  useNuiEvent('setupNavPanels', (data) => {
    dispatch(setupNavPanels(data));
  });

  useNuiEvent('displayMetadata', (data: Array<{ metadata: string; value: string }>) => {
    dispatch(setAdditionalMetadata(data));
  });

  return (
    <>
      <Fade in={inventoryVisible}>
        <div className="inventory-wrapper">
          <LeftInventory />
          <InventoryNav mode={rightPanelMode} onChange={changeRightPanelMode} />
          {rightPanelMode === 'inventory' && <RightInventory />}
          {rightPanelMode === 'craft' && navPanels.craft && <QuickCraftPanel />}
          {rightPanelMode === 'wearables' && navPanels.wearables && <WearablesPanel />}
          {rightPanelMode === 'settings' && navPanels.settings && <SettingsPanel />}
          <Tooltip />
          <InventoryContext />
        </div>
        <AmountDialog />
      </Fade>
      {/* Single always-on hotbar; interactive only while inventory is open */}
      <InventoryHotbar inventoryOpen={inventoryVisible} />
    </>
  );
};

export default Inventory;
