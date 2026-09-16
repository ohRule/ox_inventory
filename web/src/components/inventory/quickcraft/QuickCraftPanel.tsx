import React, { useCallback, useMemo, useState } from 'react';
import { useAppDispatch, useAppSelector } from '../../../store';
import { QuickCraftRecipe, selectQuickCraftRecipes } from '../../../store/quickcraft';
import { Items } from '../../../store/items';
import { getItemUrl, isSlotWithItem } from '../../../helpers';
import { selectLeftInventory } from '../../../store/inventory';
import { promptMoveAmount } from '../../../helpers/amountPrompt';
import { quickCraftItem } from '../../../thunks/quickCraftItem';
import { Locale } from '../../../store/locale';
import { selectShowDurability } from '../../../store/uiOptions';

const FAVORITES_KEY = 'ox_inventory_quickcraft_favorites';

type CategoryId = 'all' | 'weapons' | 'ammo' | 'tools' | 'medical';

const CATEGORIES: { id: CategoryId; label: string; icon: React.ReactNode }[] = [
  {
    id: 'all',
    label: 'All',
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M4 6h16v2H4V6zm0 5h16v2H4v-2zm0 5h16v2H4v-2z" />
      </svg>
    ),
  },
  {
    id: 'weapons',
    label: 'Weapons',
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M7 20v-2l8.5-8.5 2 2L9 20H7zm9.7-12.3 1.4-1.4a1.5 1.5 0 0 1 2.1 2.1l-1.4 1.4-2.1-2.1zM3 21l4.5-1.5L4.5 16.5 3 21z" />
      </svg>
    ),
  },
  {
    id: 'ammo',
    label: 'Ammo',
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 2c-1.1 0-2 .7-2 1.6V6h4V3.6C14 2.7 13.1 2 12 2zm-3 5v11.5c0 1.4 1.3 2.5 3 2.5s3-1.1 3-2.5V7H9z" />
      </svg>
    ),
  },
  {
    id: 'tools',
    label: 'Tools',
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M21.7 7.3a4 4 0 0 1-5.4 5.4l-7.2 7.2-3.1-3.1 7.2-7.2a4 4 0 0 1 5.4-5.4l-2 2 2.1 2.1 2-2z" />
      </svg>
    ),
  },
  {
    id: 'medical',
    label: 'Medical',
    icon: (
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M10 3h4v5h5v4h-5v5h-4v-5H5V8h5V3z" />
      </svg>
    ),
  },
];

const loadFavorites = (): number[] => {
  try {
    const raw = localStorage.getItem(FAVORITES_KEY);
    if (!raw) return [];
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((n) => typeof n === 'number') : [];
  } catch {
    return [];
  }
};

const saveFavorites = (ids: number[]) => {
  localStorage.setItem(FAVORITES_KEY, JSON.stringify(ids));
};

const formatDuration = (ms: number) => {
  const seconds = Math.max(1, Math.round(ms / 1000));
  return `${seconds} sec`;
};

/** Count how many of an ingredient the player currently has */
const getOwnedCount = (name: string, items: ReturnType<typeof selectLeftInventory>['items']) => {
  let total = 0;
  for (const item of items) {
    if (isSlotWithItem(item) && item.name === name) total += item.count;
  }
  return total;
};

const canCraftRecipe = (
  recipe: QuickCraftRecipe,
  items: ReturnType<typeof selectLeftInventory>['items'],
  showDurability: boolean
) => {
  for (const [name, need] of Object.entries(recipe.ingredients)) {
    if (need < 1) {
      // Tool ingredient: require durability > 0 only when durability system is on
      const tool = items.find(
        (item) =>
          isSlotWithItem(item) &&
          item.name === name &&
          (!showDurability || (item.metadata?.durability ?? 100) > 0)
      );
      if (!tool) return false;
      continue;
    }
    if (getOwnedCount(name, items) < need) return false;
  }
  return true;
};

const QuickCraftPanel: React.FC = () => {
  const dispatch = useAppDispatch();
  const recipes = useAppSelector(selectQuickCraftRecipes);
  const leftItems = useAppSelector(selectLeftInventory).items;
  const showDurability = useAppSelector(selectShowDurability);
  const isBusy = useAppSelector((state) => state.inventory.isBusy);

  const [category, setCategory] = useState<CategoryId>('all');
  const [search, setSearch] = useState('');
  const [favorites, setFavorites] = useState<number[]>(loadFavorites);

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return recipes
      .filter((recipe) => (category === 'all' ? true : recipe.category === category))
      .filter((recipe) => {
        if (!q) return true;
        return recipe.label.toLowerCase().includes(q) || recipe.name.toLowerCase().includes(q);
      })
      .sort((a, b) => {
        const af = favorites.includes(a.id) ? 0 : 1;
        const bf = favorites.includes(b.id) ? 0 : 1;
        if (af !== bf) return af - bf;
        return a.label.localeCompare(b.label);
      });
  }, [recipes, category, search, favorites]);

  const toggleFavorite = useCallback((id: number, event: React.MouseEvent) => {
    event.stopPropagation();
    setFavorites((prev) => {
      const next = prev.includes(id) ? prev.filter((x) => x !== id) : [...prev, id];
      saveFavorites(next);
      return next;
    });
  }, []);

  const onCraft = useCallback(
    async (recipe: QuickCraftRecipe) => {
      if (isBusy || !canCraftRecipe(recipe, leftItems, showDurability)) return;

      const count = await promptMoveAmount(99, 1);
      if (!count) return;

      dispatch(quickCraftItem({ recipeId: recipe.id, count }));
    },
    [dispatch, isBusy, leftItems, showDurability]
  );

  return (
    <div className="inventory-side-panel" style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
      <div className="quickcraft-categories">
        {CATEGORIES.map((cat) => (
          <button
            key={cat.id}
            type="button"
            className={`quickcraft-category-btn${category === cat.id ? ' quickcraft-category-btn-active' : ''}`}
            title={cat.label}
            aria-label={cat.label}
            onClick={() => setCategory(cat.id)}
          >
            {cat.icon}
          </button>
        ))}
      </div>

      <label className="quickcraft-search">
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
          <path d="M10 3a7 7 0 1 1 0 14 7 7 0 0 1 0-14zm0 2a5 5 0 1 0 0 10 5 5 0 0 0 0-10zm8.7 12.3-3.1-3.1 1.4-1.4 3.1 3.1-1.4 1.4z" />
        </svg>
        <input
          type="text"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder={Locale.ui_search_recipes || 'Search Recipes'}
        />
      </label>

      <div className="quickcraft-list">
        {filtered.length === 0 && (
          <div className="quickcraft-empty">{Locale.ui_no_recipes || 'No recipes found'}</div>
        )}
        {filtered.map((recipe) => {
          const craftable = canCraftRecipe(recipe, leftItems, showDurability);
          const fav = favorites.includes(recipe.id);

          return (
            <div
              key={recipe.id}
              role="button"
              tabIndex={craftable ? 0 : -1}
              className={`quickcraft-row${craftable ? '' : ' quickcraft-row-disabled'}`}
              onClick={() => onCraft(recipe)}
              onKeyDown={(event) => {
                if (craftable && (event.key === 'Enter' || event.key === ' ')) onCraft(recipe);
              }}
            >
              <button
                type="button"
                className={`quickcraft-fav${fav ? ' quickcraft-fav-on' : ''}`}
                onClick={(event) => toggleFavorite(recipe.id, event)}
                aria-label={fav ? 'Unfavorite' : 'Favorite'}
              >
                <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" aria-hidden="true">
                  <path d="M12 17.3 6.2 21l1.6-6.7L3 9.2l6.9-.6L12 2.5l2.1 6.1 6.9.6-4.8 5.1L17.8 21 12 17.3z" />
                </svg>
              </button>

              <span className="quickcraft-row-name">{recipe.label}</span>

              <div className="quickcraft-ingredients">
                {Object.entries(recipe.ingredients).map(([name, need]) => {
                  const have = getOwnedCount(name, leftItems);
                  return (
                    <div key={name} className="quickcraft-ingredient" title={Items[name]?.label || name}>
                      <img src={getItemUrl(name)} alt="" />
                      <span>{need < 1 ? '1' : `${have}/${need}`}</span>
                    </div>
                  );
                })}
              </div>

              <span className="quickcraft-arrow" aria-hidden="true">
                ›
              </span>

              <div className="quickcraft-result">
                <img src={getItemUrl(recipe.name)} alt="" />
                <span>{recipe.count}</span>
              </div>

              <span className="quickcraft-duration">{formatDuration(recipe.duration)}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
};

export default QuickCraftPanel;
