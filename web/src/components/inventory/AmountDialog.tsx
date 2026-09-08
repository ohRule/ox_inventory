import React, { useEffect, useRef, useState } from 'react';
import { Locale } from '../../store/locale';
import {
  cancelAmountPrompt,
  confirmAmountPrompt,
  getAmountPrompt,
  subscribeAmountPrompt,
} from '../../helpers/amountPrompt';

const AmountDialog: React.FC = () => {
  const [, setTick] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const prompt = getAmountPrompt();
  const [value, setValue] = useState(prompt ? String(prompt.initial) : '1');

  useEffect(() => subscribeAmountPrompt(() => setTick((tick) => tick + 1)), []);

  useEffect(() => {
    if (!prompt) return;
    setValue(String(prompt.initial));
    const id = window.setTimeout(() => {
      inputRef.current?.focus();
      inputRef.current?.select();
    }, 0);
    return () => window.clearTimeout(id);
  }, [prompt]);

  if (!prompt) return null;

  const numericValue = Math.min(prompt.max, Math.max(1, parseInt(value, 10) || 1));

  const submit = () => confirmAmountPrompt(numericValue);

  return (
    <>
      <div className="amount-dialog-overlay" onMouseDown={cancelAmountPrompt} />
      <form
        className="amount-dialog"
        onMouseDown={(event) => event.stopPropagation()}
        onSubmit={(event) => {
          event.preventDefault();
          submit();
        }}
      >
        <p className="amount-dialog-title">{prompt.title || Locale.ui_amount || 'Amount'}</p>
        {prompt.slider && (
          <input
            className="amount-dialog-slider"
            type="range"
            min={1}
            max={prompt.max}
            value={numericValue}
            onChange={(event) => setValue(event.target.value)}
          />
        )}
        <input
          ref={inputRef}
          className="amount-dialog-input"
          type="text"
          inputMode="numeric"
          value={value}
          onChange={(event) => setValue(event.target.value.replace(/\D/g, ''))}
        />
        <div className="amount-dialog-buttons">
          <button className="amount-dialog-button" type="button" onClick={cancelAmountPrompt}>
            {Locale.ui_cancel || 'Cancel'}
          </button>
          <button className="amount-dialog-button" type="submit">
            {Locale.ui_confirm || 'Confirm'}
          </button>
        </div>
      </form>
    </>
  );
};

export default AmountDialog;
