import React, { useEffect, useMemo, useRef, useState } from 'react';
import { Inventory } from '../../typings';
import InventorySlot from './InventorySlot';
import { getTotalWeight } from '../../helpers';
import { useAppSelector } from '../../store';
import { useIntersection } from '../../hooks/useIntersection';

const PAGE_SIZE = 30;

/** Small weight glyph shown next to capacity text */
const WeightIcon: React.FC = () => (
  <svg className="inventory-weight-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
    <path d="M10 4h4l1 3h4v2h-1.1l-1.7 9.2A2 2 0 0 1 14.2 20H9.8a2 2 0 0 1-2-1.8L6.1 9H5V7h4l1-3zm1.2 3 .6-1.5h.4L13 7h-1.8zM8.1 9l1.5 8h4.8l1.5-8H8.1z" />
  </svg>
);

const InventoryGrid: React.FC<{ inventory: Inventory }> = ({ inventory }) => {
  const weight = useMemo(
    () => (inventory.maxWeight !== undefined ? Math.floor(getTotalWeight(inventory.items) * 1000) / 1000 : 0),
    [inventory.maxWeight, inventory.items]
  );
  const [page, setPage] = useState(0);
  const containerRef = useRef(null);
  const { ref, entry } = useIntersection({ threshold: 0.5 });
  const isBusy = useAppSelector((state) => state.inventory.isBusy);

  useEffect(() => {
    if (entry && entry.isIntersecting) {
      setPage((prev) => ++prev);
    }
  }, [entry]);

  return (
    <div className="inventory-grid-wrapper" style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
      <div className="inventory-grid-header-wrapper">
        {inventory.maxWeight !== undefined && (
          <>
            <p className="inventory-weight-text">
              {weight / 1000}/{inventory.maxWeight / 1000}kg
            </p>
            <WeightIcon />
          </>
        )}
      </div>
      <div className="inventory-grid-container" ref={containerRef}>
        {inventory.items.slice(0, (page + 1) * PAGE_SIZE).map((item, index) => (
          <InventorySlot
            key={`${inventory.type}-${inventory.id}-${item.slot}`}
            item={item}
            ref={index === (page + 1) * PAGE_SIZE - 1 ? ref : null}
            inventoryType={inventory.type}
            inventoryGroups={inventory.groups}
            inventoryId={inventory.id}
          />
        ))}
      </div>
    </div>
  );
};

export default InventoryGrid;
