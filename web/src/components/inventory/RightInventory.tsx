import InventoryGrid from './InventoryGrid';
import ShopPanel from './ShopPanel';
import { useAppSelector } from '../../store';
import { selectRightInventory } from '../../store/inventory';
import { InventoryType } from '../../typings';

const RightInventory: React.FC = () => {
  const rightInventory = useAppSelector(selectRightInventory);

  if (rightInventory.type === InventoryType.SHOP) {
    return <ShopPanel />;
  }

  return <InventoryGrid inventory={rightInventory} />;
};

export default RightInventory;
