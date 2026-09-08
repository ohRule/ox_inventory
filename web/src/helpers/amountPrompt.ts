type AmountPrompt = {
  max: number;
  initial: number;
  title?: string;
  slider?: boolean;
  resolve: (count: number | null) => void;
};

export type AmountPromptOptions = {
  title?: string;
  slider?: boolean;
};

let current: AmountPrompt | null = null;
const listeners = new Set<() => void>();

const notify = () => listeners.forEach((listener) => listener());

/** Ask how many items to move; resolves with a count or null if cancelled. */
export const promptMoveAmount = (max: number, initial = max, options?: AmountPromptOptions) =>
  new Promise<number | null>((resolve) => {
    if (current) current.resolve(null);

    current = {
      max: Math.max(1, max),
      initial: Math.min(Math.max(1, initial), Math.max(1, max)),
      title: options?.title,
      slider: options?.slider,
      resolve,
    };

    notify();
  });

export const getAmountPrompt = () => current;

export const isAmountPromptOpen = () => current !== null;

export const subscribeAmountPrompt = (listener: () => void) => {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
};

export const confirmAmountPrompt = (count: number) => {
  if (!current) return;
  const max = current.max;
  const value = Math.min(max, Math.max(1, Math.floor(count)));
  current.resolve(value);
  current = null;
  notify();
};

export const cancelAmountPrompt = () => {
  if (!current) return;
  current.resolve(null);
  current = null;
  notify();
};
