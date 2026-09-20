import React from 'react';
import { useAppSelector } from '../../store';
import { selectIsBusy, selectLeftInventory, selectRightInventory } from '../../store/inventory';
import { InventoryType } from '../../typings';
import InventorySlot from './InventorySlot';
import { fetchNui } from '../../utils/fetchNui';
import { Locale } from '../../store/locale';
import { getItemUrl } from '../../helpers';
import { Items } from '../../store/items';

const ownedCount = (items: { name?: string; count?: number }[], name: string) =>
  items.reduce((sum, slot) => (slot?.name === name ? sum + (slot.count ?? 0) : sum), 0);

const ResearchPanel: React.FC = () => {
  const inventory = useAppSelector(selectRightInventory);
  const player = useAppSelector(selectLeftInventory);
  const isBusy = useAppSelector(selectIsBusy);
  const slot = inventory.items[0] || { slot: 1 };
  const scrapItem = inventory.unlockScrapItem || 'scrapmetal';
  const scrapLabel = Items[scrapItem]?.label || scrapItem;
  const recipe = slot.name ? inventory.researchRecipes?.[slot.name] : undefined;
  const scrapOwned = ownedCount(player.items, scrapItem);
  const scrapNeed = recipe?.scrap || 0;
  const empty = !slot.name;
  const canResearch = !!(recipe && !recipe.unlocked && scrapOwned >= scrapNeed);

  let status = Locale.ui_research_insert || 'Place an item to research';
  if (slot.name && !recipe) status = Locale.ui_research_cannot || 'This item cannot be researched';
  else if (recipe?.unlocked) status = Locale.ui_researched || 'Already researched';
  else if (recipe && scrapOwned < scrapNeed) status = `${scrapOwned}/${scrapNeed} ${scrapLabel}`;
  else if (recipe) status = Locale.ui_research || 'Research';

  return (
    <div className="inventory-side-panel research-panel" style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
      <div className="research-header">
        <p className="research-title">{inventory.label || Locale.research_table || 'Research Table'}</p>
      </div>

      <p className="research-hint">{Locale.ui_research_insert || 'Place an item to research'}</p>
      <div className="research-slot-wrap">
        <InventorySlot
          item={slot}
          inventoryId={inventory.id}
          inventoryType={InventoryType.RESEARCH}
          inventoryGroups={inventory.groups}
        />
      </div>

      {recipe && !recipe.unlocked && (
        <div className="research-cost">
          <div className="research-cost-icon" style={{ backgroundImage: `url(${getItemUrl(scrapItem) || 'none'})` }} />
          <span className={scrapOwned < scrapNeed ? 'research-cost-low' : ''}>
            {scrapOwned}/{scrapNeed}
          </span>
          <span>{scrapLabel}</span>
        </div>
      )}

      <p className="research-status">{empty ? '' : status}</p>
      <button
        type="button"
        className="research-button"
        disabled={!canResearch}
        onClick={() => fetchNui('researchCraftRecipe', {})}
      >
        {Locale.ui_research || 'Research'}
      </button>
    </div>
  );
};

export default ResearchPanel;
