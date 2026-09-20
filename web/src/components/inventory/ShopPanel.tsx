import React, { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectRightInventory, selectIsBusy } from '../../store/inventory';
import {
  addToCart,
  bindShopCart,
  clearCart,
  removeFromCart,
  selectShopCartLines,
  selectShopCartTotals,
  setCartQty,
} from '../../store/shopCart';
import { canPurchaseItem, getItemUrl, isSlotWithItem } from '../../helpers';
import { Locale } from '../../store/locale';
import { Items } from '../../store/items';
import { InventoryType, SlotWithItem } from '../../typings';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import { buyCart } from '../../thunks/buyCart';
import { useIntersection } from '../../hooks/useIntersection';

const PAGE_SIZE = 30;

const formatMoneyPrice = (amount: number) =>
  `${Locale.$ || '$'}${amount.toLocaleString('en-us')}`;

const formatLinePrice = (price: number, currency?: string) => {
  if (!currency || currency === 'money' || currency === 'black_money') return formatMoneyPrice(price);
  return price.toLocaleString('en-us');
};

/** Catalogue slot — click adds to cart (no drag) */
const ShopSlot: React.FC<{
  item: SlotWithItem;
  inventoryGroups: ReturnType<typeof selectRightInventory>['groups'];
  onAdd: () => void;
  disabled: boolean;
  sentinelRef?: React.Ref<HTMLDivElement>;
}> = ({ item, inventoryGroups, onAdd, disabled, sentinelRef }) => {
  const dispatch = useAppDispatch();
  const timerRef = useRef<number | null>(null);
  const purchasable = canPurchaseItem(item, { type: InventoryType.SHOP, groups: inventoryGroups });

  return (
    <div
      ref={sentinelRef}
      role="button"
      tabIndex={purchasable && !disabled ? 0 : -1}
      className={`inventory-slot shop-slot${purchasable ? '' : ' shop-slot-disabled'}`}
      style={{
        filter: purchasable ? undefined : 'brightness(80%) grayscale(100%)',
        backgroundImage: `url(${getItemUrl(item) || 'none'})`,
        cursor: purchasable && !disabled ? 'pointer' : 'default',
      }}
      onClick={() => {
        if (!purchasable || disabled) return;
        dispatch(closeTooltip());
        onAdd();
      }}
      onKeyDown={(event) => {
        if (event.key === 'Enter' || event.key === ' ') {
          event.preventDefault();
          if (!purchasable || disabled) return;
          onAdd();
        }
      }}
      onMouseEnter={() => {
        timerRef.current = window.setTimeout(() => {
          dispatch(openTooltip({ item, inventoryType: InventoryType.SHOP }));
        }, 150) as unknown as number;
      }}
      onMouseLeave={() => {
        dispatch(closeTooltip());
        if (timerRef.current) {
          clearTimeout(timerRef.current);
          timerRef.current = null;
        }
      }}
    >
      <div className="item-slot-wrapper">
        {item.price !== undefined && (
          <div>
            {item.currency !== 'money' && item.currency !== 'black_money' && item.price > 0 && item.currency ? (
              <div className="item-slot-currency-wrapper">
                <img
                  src={getItemUrl(item.currency) || 'none'}
                  alt=""
                  style={{
                    imageRendering: '-webkit-optimize-contrast',
                    height: 'auto',
                    width: '2vh',
                    backfaceVisibility: 'hidden',
                    transform: 'translateZ(0)',
                  }}
                />
                <p>{item.price.toLocaleString('en-us')}</p>
              </div>
            ) : (
              item.price > 0 && (
                <div
                  className="item-slot-price-wrapper"
                  style={{ color: item.currency === 'money' || !item.currency ? '#2ECC71' : '#E74C3C' }}
                >
                  <p>
                    {Locale.$ || '$'}
                    {item.price.toLocaleString('en-us')}
                  </p>
                </div>
              )
            )}
          </div>
        )}
        <p className="item-slot-count">{item.count ? item.count.toLocaleString('en-us') + `x` : ''}</p>
      </div>
    </div>
  );
};

const ShopPanel: React.FC = () => {
  const dispatch = useAppDispatch();
  const shop = useAppSelector(selectRightInventory);
  const lines = useAppSelector(selectShopCartLines);
  const totals = useAppSelector(selectShopCartTotals);
  const isBusy = useAppSelector(selectIsBusy);
  const [page, setPage] = useState(0);
  const { ref, entry } = useIntersection({ threshold: 0.5 });

  useEffect(() => {
    dispatch(bindShopCart(shop.id ? String(shop.id) : null));
  }, [dispatch, shop.id]);

  useEffect(() => {
    for (const line of lines) {
      const shopItem = shop.items.find((entry) => entry.slot === line.shopSlot);
      if (!shopItem || !isSlotWithItem(shopItem, false)) continue;
      if (shopItem.count !== undefined && line.count > shopItem.count) {
        dispatch(setCartQty({ shopSlot: line.shopSlot, count: shopItem.count }));
      }
    }
  }, [dispatch, shop.items, lines]);

  useEffect(() => {
    if (entry && entry.isIntersecting) {
      setPage((prev) => prev + 1);
    }
  }, [entry]);

  const shopItems = useMemo(
    () => shop.items.filter((item): item is SlotWithItem => isSlotWithItem(item, false)),
    [shop.items]
  );

  const visibleItems = shopItems.slice(0, (page + 1) * PAGE_SIZE);

  const onAddItem = useCallback(
    (item: SlotWithItem) => {
      if (!canPurchaseItem(item, { type: InventoryType.SHOP, groups: shop.groups })) return;

      const label = item.metadata?.label || Items[item.name]?.label || item.name;
      dispatch(
        addToCart({
          shopSlot: item.slot,
          name: item.name,
          label,
          price: item.price ?? 0,
          currency: item.currency,
          maxCount: item.count,
        })
      );
    },
    [dispatch, shop.groups]
  );

  const onCheckout = useCallback(async () => {
    if (isBusy || lines.length === 0) return;

    const result = await dispatch(
      buyCart({
        items: lines.map((line) => ({ fromSlot: line.shopSlot, count: line.count })),
      })
    );

    if (buyCart.fulfilled.match(result)) {
      dispatch(clearCart());
    }
  }, [dispatch, isBusy, lines]);

  const totalEntries = Object.entries(totals);

  return (
    <div className="shop-panel inventory-side-panel" style={{ pointerEvents: isBusy ? 'none' : 'auto' }}>
      <div className="shop-header">
        <p className="shop-title">{shop.label || Locale.ui_shop || 'Shop'}</p>
      </div>

      <div className="shop-catalogue">
        {visibleItems.map((item, index) => (
          <ShopSlot
            key={`shop-${shop.id}-${item.slot}`}
            item={item}
            inventoryGroups={shop.groups}
            disabled={isBusy}
            onAdd={() => onAddItem(item)}
            sentinelRef={index === visibleItems.length - 1 ? ref : undefined}
          />
        ))}
      </div>

      <div className="shop-cart">
        <div className="shop-cart-list">
          {lines.length === 0 && (
            <div className="shop-cart-empty">{Locale.ui_cart_empty || 'Cart is empty'}</div>
          )}
          {lines.map((line) => (
            <div key={line.shopSlot} className="shop-cart-row">
              <div className="shop-cart-qty">
                <button
                  type="button"
                  className="shop-cart-qty-btn"
                  aria-label="Decrease"
                  onClick={() => dispatch(setCartQty({ shopSlot: line.shopSlot, count: line.count - 1 }))}
                >
                  −
                </button>
                <span className="shop-cart-qty-value">{line.count}</span>
                <button
                  type="button"
                  className="shop-cart-qty-btn"
                  aria-label="Increase"
                  disabled={line.maxCount !== undefined && line.count >= line.maxCount}
                  onClick={() => dispatch(setCartQty({ shopSlot: line.shopSlot, count: line.count + 1 }))}
                >
                  +
                </button>
              </div>
              <span className="shop-cart-name">{line.label}</span>
              <span
                className="shop-cart-line-price"
                style={{ color: !line.currency || line.currency === 'money' ? '#2ECC71' : '#E74C3C' }}
              >
                {line.currency && line.currency !== 'money' && line.currency !== 'black_money' ? (
                  <>
                    <img src={getItemUrl(line.currency) || 'none'} alt="" className="shop-cart-currency-icon" />
                    {formatLinePrice(line.price * line.count, line.currency)}
                  </>
                ) : (
                  formatLinePrice(line.price * line.count, line.currency)
                )}
              </span>
              <button
                type="button"
                className="shop-cart-remove"
                aria-label="Remove"
                onClick={() => dispatch(removeFromCart(line.shopSlot))}
              >
                ×
              </button>
            </div>
          ))}
        </div>

        <div className="shop-cart-footer">
          <div className="shop-cart-total-row">
            <span>{Locale.ui_cart_total || 'Total:'}</span>
            <span className="shop-cart-total-value">
              {totalEntries.length === 0
                ? formatMoneyPrice(0)
                : totalEntries.map(([currency, amount], index) => (
                    <span key={currency}>
                      {index > 0 ? ' + ' : ''}
                      {currency !== 'money' && currency !== 'black_money' ? (
                        <>
                          <img src={getItemUrl(currency) || 'none'} alt="" className="shop-cart-currency-icon" />
                          {amount.toLocaleString('en-us')}
                        </>
                      ) : (
                        formatMoneyPrice(amount)
                      )}
                    </span>
                  ))}
            </span>
          </div>
          <button
            type="button"
            className="shop-checkout-btn"
            disabled={lines.length === 0 || isBusy}
            onClick={onCheckout}
          >
            {Locale.ui_checkout || 'Checkout'}
          </button>
        </div>
      </div>
    </div>
  );
};

export default ShopPanel;
