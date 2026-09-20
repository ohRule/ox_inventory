import InventoryGrid from './InventoryGrid';
import ShopPanel from './ShopPanel';
import RecyclerPanel from './RecyclerPanel';
import TechTreePanel from './TechTreePanel';
import ResearchPanel from './ResearchPanel';
import { useAppSelector } from '../../store';
import { selectRightInventory } from '../../store/inventory';
import { InventoryType } from '../../typings';

const RightInventory: React.FC = () => {
  const rightInventory = useAppSelector(selectRightInventory);

  // Pawn + trader use the original shop grid (drag to buy/sell, no cart)
  if (rightInventory.type === InventoryType.SHOP && rightInventory.style !== 'pawn' && rightInventory.style !== 'trader') {
    return <ShopPanel />;
  }

  if (rightInventory.type === InventoryType.RECYCLER || rightInventory.type === InventoryType.FURNACE) {
    return <RecyclerPanel />;
  }

  if (rightInventory.type === InventoryType.RESEARCH) {
    return <ResearchPanel />;
  }

  if (rightInventory.type === InventoryType.CRAFTING && rightInventory.techTree) {
    return <TechTreePanel />;
  }

  return <InventoryGrid inventory={rightInventory} />;
};

export default RightInventory;
