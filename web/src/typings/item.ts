export type ItemData = {
  name: string;
  label: string;
  stack: boolean;
  usable: boolean;
  close: boolean;
  count: number;
  description?: string;
  buttons?: string[];
  ammoName?: string;
  image?: string;
  weapon?: boolean | number;
  wearable?: string;
  // An attachment: dropped on a gun, it's fitted to it
  component?: boolean;
};
