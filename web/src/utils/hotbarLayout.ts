import { fetchNui } from './fetchNui';

/**
 * Keep in step with ox_lib `web/src/features/progress/hotbarLayout.ts`
 * and the hotbar rules in index.scss (`bottom: 2vh`, `$gridSize: 9.6vh`).
 */
const HOTBAR_GAP_VH = 0.6;

let lastPayload = '';

/** Tell ox_lib where the progress bar should sit, just above the hotbar. */
export const syncHotbarLayout = () => {
  requestAnimationFrame(() => {
    const style = getComputedStyle(document.documentElement);
    const scale = Number(style.getPropertyValue('--inv-hotbar-scale')) || 1;
    const highlight = style.getPropertyValue('--inv-highlight').trim();
    const opacity = Number(style.getPropertyValue('--inv-panel-alpha')) || 0.55;
    const slots = document.querySelector('.hotbar-slots');
    // Slots are unmounted when the player or a script hides the HUD hotbar.
    const active = !!slots;
    let bottom: number | null = null;

    // Prefer the real slot box so scale (transform-origin: center bottom) is included.
    if (slots) {
      const rect = slots.getBoundingClientRect();
      const gap = (HOTBAR_GAP_VH / 100) * window.innerHeight;
      bottom = Math.round(window.innerHeight - rect.top + gap);
    }

    const payload = JSON.stringify({ scale, bottom, highlight, opacity, active });
    if (payload === lastPayload) return;
    lastPayload = payload;

    void fetchNui('syncHotbarLayout', { scale, bottom, highlight, opacity, active }).catch(() => undefined);
  });
};
