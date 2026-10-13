import { useEffect, useRef } from 'react';
import { noop } from '../utils/misc';
import { fetchNui } from '../utils/fetchNui';
import { closeTooltip } from '../store/tooltip';
import { useAppDispatch } from '../store';
import { closeContextMenu } from '../store/contextMenu';
import { cancelAmountPrompt, isAmountPromptOpen } from '../helpers/amountPrompt';

type FrameVisibleSetter = (bool: boolean) => void;

// Escape always; Tab too (opens inventory, and frontend wearables can eat the game keybind)
const LISTENED_KEYS = ['Escape', 'Tab'];

// Basic hook to listen for key presses in NUI in order to exit
export const useExitListener = (visibleSetter: FrameVisibleSetter) => {
  const setterRef = useRef<FrameVisibleSetter>(noop);
  const dispatch = useAppDispatch();

  useEffect(() => {
    setterRef.current = visibleSetter;
  }, [visibleSetter]);

  useEffect(() => {
    const keyHandler = (e: KeyboardEvent) => {
      if (LISTENED_KEYS.includes(e.code)) {
        // Stop Tab from jumping focus inside the NUI
        if (e.code === 'Tab') {
          e.preventDefault();
        }

        if (isAmountPromptOpen()) {
          cancelAmountPrompt();
          return;
        }

        setterRef.current(false);
        dispatch(closeTooltip());
        dispatch(closeContextMenu());
        fetchNui('exit');
      }
    };

    // keydown so we can preventDefault Tab before the browser moves focus
    window.addEventListener('keydown', keyHandler);

    return () => window.removeEventListener('keydown', keyHandler);
  }, []);
};
