import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectLeftInventory, selectRightInventory } from '../../store/inventory';
import { craftItem } from '../../thunks/craftItem';
import { Items } from '../../store/items';
import { canCraftItem, getItemUrl } from '../../helpers';
import { InventoryType, SlotWithItem } from '../../typings';
import { Locale } from '../../store/locale';
import { fetchNui } from '../../utils/fetchNui';
import { promptMoveAmount } from '../../helpers/amountPrompt';

type Recipe = SlotWithItem & {
  previousItem?: string;
  locked?: boolean;
  unlockItem?: { name: string; count?: number };
  unlockScrap?: number;
  researchScrap?: number;
};
type TreeNode = { recipe: Recipe; children: TreeNode[] };

const ownedCount = (items: { name?: string; count?: number }[], name: string) =>
  items.reduce((sum, slot) => (slot?.name === name ? sum + (slot.count ?? 0) : sum), 0);

const TechTreePanel: React.FC = () => {
  const dispatch = useAppDispatch();
  const shop = useAppSelector(selectRightInventory);
  const player = useAppSelector(selectLeftInventory);
  const isBusy = useAppSelector((state) => state.inventory.isBusy);
  const scrapItem = shop.unlockScrapItem || 'scrapmetal';

  const recipes = useMemo((): Recipe[] => {
    return (shop.items || []).filter((entry): entry is Recipe => !!entry.name && !!entry.slot);
  }, [shop.items]);

  const treeRoots = useMemo(() => {
    const children = new Map<string | null, Recipe[]>();
    for (const recipe of recipes) {
      const key = recipe.previousItem || null;
      const list = children.get(key) || [];
      list.push(recipe);
      children.set(key, list);
    }
    children.forEach((list) => list.sort((a, b) => a.slot - b.slot));
    const build = (recipe: Recipe): TreeNode => ({
      recipe,
      children: (children.get(recipe.name) || []).map(build),
    });
    return (children.get(null) || []).map(build);
  }, [recipes]);

  const [selectedSlot, setSelectedSlot] = useState<number | null>(null);
  const selected = useMemo(
    () => (selectedSlot != null ? recipes.find((recipe) => recipe.slot === selectedSlot) || null : null),
    [recipes, selectedSlot]
  );

  useEffect(() => {
    if (selectedSlot == null && recipes[0]) setSelectedSlot(recipes[0].slot);
  }, [recipes, selectedSlot]);

  const [pan, setPan] = useState({ x: 0, y: 0 });
  const panStart = useRef<{ x: number; y: number; mouseX: number; mouseY: number } | null>(null);

  const onTreeMouseDown = useCallback(
    (event: React.MouseEvent) => {
      if ((event.target as HTMLElement).closest('.crafting-panel-techtree-node')) return;
      panStart.current = { x: pan.x, y: pan.y, mouseX: event.clientX, mouseY: event.clientY };
    },
    [pan.x, pan.y]
  );

  useEffect(() => {
    const move = (event: MouseEvent) => {
      if (!panStart.current) return;
      setPan({
        x: panStart.current.x + event.clientX - panStart.current.mouseX,
        y: panStart.current.y + event.clientY - panStart.current.mouseY,
      });
    };
    const up = () => {
      panStart.current = null;
    };
    window.addEventListener('mousemove', move);
    window.addEventListener('mouseup', up);
    return () => {
      window.removeEventListener('mousemove', move);
      window.removeEventListener('mouseup', up);
    };
  }, []);

  const onCraft = useCallback(
    (recipe: Recipe) => {
      if (recipe.locked || !canCraftItem(recipe, InventoryType.CRAFTING)) return;
      promptMoveAmount(99, 1, { title: Locale.ui_craft || 'Craft' }).then((count) => {
        if (!count) return;
        const stack = player.items.find((slot) => slot.name === recipe.name);
        const empty = player.items.find((slot) => !slot.name);
        dispatch(
          craftItem({
            fromSlot: recipe.slot,
            toSlot: stack?.slot || empty?.slot || 1,
            fromType: InventoryType.CRAFTING,
            toType: InventoryType.PLAYER,
            count,
          })
        );
      });
    },
    [dispatch, player.items]
  );

  const onUnlock = useCallback((slot: number, method: 'blueprint' | 'scrap') => {
    fetchNui('unlockCraftRecipe', { recipeSlot: slot, method });
  }, []);

  const renderNode = (node: TreeNode) => {
    const locked = node.recipe.locked === true;
    const selectedNode = selectedSlot === node.recipe.slot;
    return (
      <button
        type="button"
        className={`crafting-panel-techtree-node${locked ? ' crafting-panel-techtree-node--locked' : ''}${selectedNode ? ' crafting-panel-techtree-node--selected' : ''}`}
        onClick={() => setSelectedSlot(node.recipe.slot)}
        title={Items[node.recipe.name]?.label || node.recipe.name}
      >
        <div className="crafting-panel-techtree-node-icon" style={{ backgroundImage: `url(${getItemUrl(node.recipe) || 'none'})` }} />
        {locked && (
          <span className="crafting-panel-techtree-node-lock" aria-hidden>
            🔒
          </span>
        )}
      </button>
    );
  };

  // CSS draws the T-connectors from each child's box so lines stay on node centers.
  const renderBranch = (node: TreeNode): React.ReactNode => {
    const kids = node.children;
    return (
      <div key={node.recipe.slot} className="crafting-panel-techtree-branch">
        {renderNode(node)}
        {kids.length > 0 && (
          <div
            className={`crafting-panel-techtree-children${kids.length === 1 ? ' crafting-panel-techtree-children--single' : ''}`}
          >
            {kids.map((child) => (
              <div key={child.recipe.slot} className="crafting-panel-techtree-child">
                {renderBranch(child)}
              </div>
            ))}
          </div>
        )}
      </div>
    );
  };

  const parentRecipe = selected?.previousItem ? recipes.find((recipe) => recipe.name === selected.previousItem) : null;
  const parentLocked = !!(parentRecipe && parentRecipe.locked);
  const unlockNeed = selected?.unlockItem;
  const unlockScrap = selected?.unlockScrap && selected.unlockScrap > 0 ? selected.unlockScrap : 0;
  const hasBlueprint = !!(unlockNeed && ownedCount(player.items, unlockNeed.name) >= (unlockNeed.count ?? 1));
  const hasScrap = ownedCount(player.items, scrapItem) >= unlockScrap;
  const scrapLabel = Items[scrapItem]?.label || scrapItem;

  return (
    <div className="inventory-side-panel crafting-panel crafting-panel--techtree" style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
      <div className="crafting-panel-header">
        <p>{shop.label || Locale.crafting_bench || 'Workbench'}</p>
      </div>
      <div className="crafting-panel-techtree">
        <div className="crafting-panel-techtree-tree" onMouseDown={onTreeMouseDown} role="presentation">
          <span className="crafting-panel-techtree-pan-hint">Drag to pan</span>
          <div className="crafting-panel-techtree-viewport-content" style={{ transform: `translate(${pan.x}px, ${pan.y}px)` }}>
            <div className="crafting-panel-techtree-chain">
              <div className="crafting-panel-techtree-roots">{treeRoots.map((node) => renderBranch(node))}</div>
            </div>
          </div>
        </div>
        <div className="crafting-panel-techtree-sidebar">
          <div className="crafting-panel-techtree-detail">
            {selected ? (
              <>
                <p className="crafting-panel-techtree-detail-title">{Items[selected.name]?.label || selected.name}</p>
                <div className="crafting-panel-techtree-detail-ingredients">
                  {selected.ingredients &&
                    Object.entries(selected.ingredients).map(([name, required]) => {
                      const owned = ownedCount(player.items, name);
                      const enough = required < 1 ? owned >= 1 : owned >= required;
                      return (
                        <div key={name} className="crafting-panel-techtree-detail-ingredient">
                          <div
                            className="crafting-panel-techtree-detail-ingredient-icon"
                            style={{ backgroundImage: `url(${getItemUrl(name) || 'none'})` }}
                          />
                          <span className={!enough ? 'crafting-panel-techtree-detail-ingredient-count--low' : ''}>
                            {required < 1 ? (owned >= 1 ? '1' : '0/1') : `${owned}/${required}`}
                          </span>
                          <span>{Items[name]?.label || name}</span>
                        </div>
                      );
                    })}
                </div>
                <div className="crafting-panel-techtree-detail-actions">
                  {parentLocked && parentRecipe && selected.locked && (
                    <p className="crafting-panel-techtree-detail-require-parent">
                      {(Locale.crafting_unlock_parent_first || 'Unlock %s first').replace(
                        '%s',
                        Items[parentRecipe.name]?.label || parentRecipe.name
                      )}
                    </p>
                  )}
                  {selected.locked && unlockNeed && (
                    <button
                      type="button"
                      className="crafting-panel-techtree-detail-unlock"
                      disabled={parentLocked || !hasBlueprint}
                      onClick={() => onUnlock(selected.slot, 'blueprint')}
                    >
                      {Locale.ui_unlock || 'Unlock'} ({unlockNeed.count ?? 1}x {Items[unlockNeed.name]?.label || unlockNeed.name})
                    </button>
                  )}
                  {selected.locked && unlockScrap > 0 && (
                    <button
                      type="button"
                      className="crafting-panel-techtree-detail-unlock"
                      disabled={parentLocked || !hasScrap}
                      onClick={() => onUnlock(selected.slot, 'scrap')}
                    >
                      {Locale.ui_unlock || 'Unlock'} ({unlockScrap}x {scrapLabel})
                    </button>
                  )}
                  {!selected.locked && (
                    <button
                      type="button"
                      className="crafting-panel-techtree-detail-craft"
                      disabled={!canCraftItem(selected, InventoryType.CRAFTING)}
                      onClick={() => onCraft(selected)}
                    >
                      {Locale.ui_craft || 'Craft'}
                    </button>
                  )}
                </div>
              </>
            ) : (
              <p className="crafting-panel-techtree-detail-empty">{Locale.ui_select_recipe || 'Select a recipe'}</p>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};

export default TechTreePanel;
