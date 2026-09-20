import React, { useEffect, useMemo, useState } from 'react';
import { useAppSelector } from '../../store';
import { selectIsBusy, selectRightInventory } from '../../store/inventory';
import { InventoryType, RecyclerProcess } from '../../typings';
import InventorySlot from './InventorySlot';
import useNuiEvent from '../../hooks/useNuiEvent';
import { fetchNui } from '../../utils/fetchNui';
import { Locale } from '../../store/locale';
import { getItemUrl } from '../../helpers';

type RecyclerStatePayload = {
  running?: boolean;
  process?: RecyclerProcess | null;
};

const RecyclerPanel: React.FC = () => {
  const inventory = useAppSelector(selectRightInventory);
  const isBusy = useAppSelector(selectIsBusy);
  const isFurnace = inventory.type === InventoryType.FURNACE;
  const slotType = isFurnace ? InventoryType.FURNACE : InventoryType.RECYCLER;
  const inputSlots = inventory.inputSlots || Math.floor(inventory.slots / 2);
  const oreSlots = inventory.oreSlots || (isFurnace ? inputSlots : 0);
  const fuelSlots = inventory.fuelSlots || 0;

  const [running, setRunning] = useState(!!inventory.running);
  const [process, setProcess] = useState<RecyclerProcess | null>(inventory.process ?? null);
  const [progress, setProgress] = useState(0);

  useEffect(() => {
    setRunning(!!inventory.running);
    setProcess(inventory.process ?? null);
  }, [inventory.id, inventory.running, inventory.process]);

  useNuiEvent<RecyclerStatePayload>('recyclerState', (data) => {
    if (inventory.type === InventoryType.FURNACE) return;
    setRunning(!!data.running);
    setProcess(data.process ?? null);
  });

  useNuiEvent<RecyclerStatePayload>('furnaceState', (data) => {
    if (inventory.type !== InventoryType.FURNACE) return;
    setRunning(!!data.running);
    setProcess(data.process ?? null);
  });

  useEffect(() => {
    if (!process) {
      setProgress(0);
      return;
    }

    if (process.blocked || process.needFuel) {
      setProgress(1);
      return;
    }

    const startedAt = Date.now();
    const already = process.duration - process.remaining;

    const tick = () => {
      const elapsed = already + (Date.now() - startedAt);
      setProgress(Math.min(1, elapsed / process.duration));
    };

    tick();
    const id = window.setInterval(tick, 50);
    return () => window.clearInterval(id);
  }, [process]);

  const oreItems = useMemo(
    () => inventory.items.filter((item) => item.slot <= (isFurnace ? oreSlots : inputSlots)),
    [inventory.items, isFurnace, oreSlots, inputSlots]
  );
  const fuelItems = useMemo(
    () =>
      isFurnace
        ? inventory.items.filter((item) => item.slot > oreSlots && item.slot <= oreSlots + fuelSlots)
        : [],
    [inventory.items, isFurnace, oreSlots, fuelSlots]
  );
  const outputItems = useMemo(
    () => inventory.items.filter((item) => item.slot > (isFurnace ? oreSlots + fuelSlots : inputSlots)),
    [inventory.items, isFurnace, oreSlots, fuelSlots, inputSlots]
  );

  const idleText = isFurnace
    ? Locale.ui_furnace_idle || 'Add ore and fuel, then light it'
    : Locale.ui_recycler_idle || 'Insert items and turn on';
  const fullText = Locale.ui_recycler_full || 'Output is full';
  const fuelText = Locale.ui_furnace_fuel || 'Need fuel';

  const statusText = process?.needFuel
    ? fuelText
    : process?.blocked
      ? fullText
      : process
        ? process.label
        : idleText;

  const toggle = () => {
    fetchNui<{ success: boolean; running?: boolean; process?: RecyclerProcess | null }>(
      isFurnace ? 'toggleFurnace' : 'toggleRecycler',
      { running: !running }
    ).then((result) => {
      if (!result?.success) return;
      setRunning(!!result.running);
      setProcess(result.process ?? null);
    });
  };

  return (
    <div className="inventory-side-panel recycler-panel" style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
      <div className="recycler-header">
        <p className="recycler-title">
          {inventory.label || (isFurnace ? Locale.ui_furnace : Locale.ui_recycler) || (isFurnace ? 'Furnace' : 'Recycler')}
        </p>
      </div>

      <p className="recycler-section-label">
        {(isFurnace ? Locale.ui_furnace_input : Locale.ui_recycler_input) || (isFurnace ? 'To Smelt' : 'To Recycle')}
      </p>
      <div className="recycler-grid">
        {oreItems.map((item) => (
          <InventorySlot
            key={`${inventory.id}-${item.slot}`}
            item={item}
            inventoryId={inventory.id}
            inventoryType={slotType}
            inventoryGroups={inventory.groups}
            locked={process?.slot === item.slot}
            highlighted={process?.slot === item.slot}
          />
        ))}
      </div>

      {isFurnace && (
        <>
          <p className="recycler-section-label">{Locale.ui_furnace_fuel_input || 'Fuel'}</p>
          <div className="recycler-grid">
            {fuelItems.map((item) => (
              <InventorySlot
                key={`${inventory.id}-${item.slot}`}
                item={item}
                inventoryId={inventory.id}
                inventoryType={slotType}
                inventoryGroups={inventory.groups}
              />
            ))}
          </div>
        </>
      )}

      <div className="recycler-controls">
        <button
          type="button"
          className={`recycler-toggle${running ? ' recycler-toggle-on' : ''}`}
          onClick={toggle}
        >
          {running ? Locale.ui_recycler_on || 'ON' : Locale.ui_recycler_off || 'OFF'}
        </button>

        <div className="recycler-status">
          {process?.name && (
            <div
              className="recycler-status-icon"
              style={{ backgroundImage: `url(${getItemUrl(process.name) || 'none'})` }}
            />
          )}
          <p className="recycler-status-text">{statusText}</p>
        </div>

        <div className="recycler-progress">
          <div className="recycler-progress-fill" style={{ width: `${progress * 100}%` }} />
        </div>
      </div>

      <p className="recycler-section-label">
        {(isFurnace ? Locale.ui_furnace_output : Locale.ui_recycler_output) || (isFurnace ? 'Smelted' : 'Recycled')}
      </p>
      <div className="recycler-grid">
        {outputItems.map((item) => (
          <InventorySlot
            key={`${inventory.id}-${item.slot}`}
            item={item}
            inventoryId={inventory.id}
            inventoryType={slotType}
            inventoryGroups={inventory.groups}
            disableDrop
          />
        ))}
      </div>
    </div>
  );
};

export default RecyclerPanel;
