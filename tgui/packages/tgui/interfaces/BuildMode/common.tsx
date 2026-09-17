import { Box } from 'tgui-core/components';

type Flag = boolean | number;
export type CatalogItem = {
  name: string;
  desc: string;
  path: string;
  category: string;
  icon?: string;
  favorite: Flag;
  is_item: Flag;
  is_turf: Flag;
};
export type CatalogOption = { id: string; name: string };

export type BuildModeData = {
  categories: CatalogOption[];
  armor_classes: CatalogOption[];
  coverage_zones: CatalogOption[];
  max_search_length: number;
  max_offset: number;
  items: CatalogItem[];
  selected?: CatalogItem | null;
  counts: Record<string, number>;
  total: number;
  matches: number;
  page: number;
  pages: number;
  category: string;
  subcategory: string;
  subcategories: CatalogOption[];
  armor_class: string;
  coverage: string;
  search: string;
  favorites_count: number;
  recent_count: number;
  max_favorites: number;
  max_amount: number;
  amount: number;
  direction: number;
  pixel_x: number;
  pixel_y: number;
  armed: Flag;
  can_hands: Flag;
  mode: string;
  status?: string;
};

export const Sprite = ({
  item,
  large = false,
}: {
  item: CatalogItem;
  large?: boolean;
}) => (
  <Box
    className={`BuildMode__sprite${large ? ' BuildMode__sprite--large' : ''}`}
  >
    {item.icon ? <img src={item.icon} alt={item.name} /> : <span>?</span>}
  </Box>
);
