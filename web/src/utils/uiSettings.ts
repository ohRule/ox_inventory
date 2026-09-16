const STORAGE_KEY = 'ox_inventory_ui_settings';

export type HighlightId = 'grey' | 'white' | 'blue' | 'green' | 'amber' | 'rose' | 'custom';

export type UiSettings = {
  highlight: HighlightId;
  /** Hex colour used when highlight === 'custom' */
  customHighlight: string;
  /** Slot / panel background opacity (0.25–0.85) */
  panelOpacity: number;
  /** Hotbar size multiplier (0.75–1.35) */
  hotbarScale: number;
};

/** RGB triplets used with CSS `rgba(var(--inv-highlight), a)` */
export const HIGHLIGHT_PRESETS: Record<Exclude<HighlightId, 'custom'>, { label: string; rgb: string; hex: string }> =
  {
    grey: { label: 'Grey', rgb: '180, 180, 185', hex: '#b4b4b9' },
    white: { label: 'White', rgb: '235, 235, 238', hex: '#ebebee' },
    blue: { label: 'Blue', rgb: '110, 160, 220', hex: '#6ea0dc' },
    green: { label: 'Green', rgb: '110, 190, 140', hex: '#6ebe8c' },
    amber: { label: 'Amber', rgb: '220, 170, 90', hex: '#dcaa5a' },
    rose: { label: 'Rose', rgb: '210, 120, 140', hex: '#d2788c' },
  };

export const DEFAULT_UI_SETTINGS: UiSettings = {
  highlight: 'grey',
  customHighlight: '#b4b4b9',
  panelOpacity: 0.55,
  hotbarScale: 1,
};

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

/** Normalise #rgb / #rrggbb into #rrggbb, or null if invalid */
export const normaliseHex = (value: string): string | null => {
  const raw = value.trim().replace(/^#/, '');
  if (/^[0-9a-fA-F]{3}$/.test(raw)) {
    return `#${raw[0]}${raw[0]}${raw[1]}${raw[1]}${raw[2]}${raw[2]}`.toLowerCase();
  }
  if (/^[0-9a-fA-F]{6}$/.test(raw)) {
    return `#${raw}`.toLowerCase();
  }
  return null;
};

export const hexToRgbTriplet = (hex: string): string => {
  const normalised = normaliseHex(hex) ?? DEFAULT_UI_SETTINGS.customHighlight;
  const value = normalised.slice(1);
  const r = parseInt(value.slice(0, 2), 16);
  const g = parseInt(value.slice(2, 4), 16);
  const b = parseInt(value.slice(4, 6), 16);
  return `${r}, ${g}, ${b}`;
};

export const resolveHighlightRgb = (settings: UiSettings): string => {
  if (settings.highlight === 'custom') {
    return hexToRgbTriplet(settings.customHighlight);
  }
  return HIGHLIGHT_PRESETS[settings.highlight]?.rgb ?? HIGHLIGHT_PRESETS.grey.rgb;
};

export const loadUiSettings = (): UiSettings => {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return { ...DEFAULT_UI_SETTINGS };
    const parsed = JSON.parse(raw) as Partial<UiSettings>;

    const customHighlight = normaliseHex(parsed.customHighlight || '') ?? DEFAULT_UI_SETTINGS.customHighlight;
    let highlight: HighlightId = DEFAULT_UI_SETTINGS.highlight;

    if (parsed.highlight === 'custom') {
      highlight = 'custom';
    } else if (parsed.highlight && parsed.highlight in HIGHLIGHT_PRESETS) {
      highlight = parsed.highlight;
    }

    return {
      highlight,
      customHighlight,
      panelOpacity: clamp(Number(parsed.panelOpacity) || DEFAULT_UI_SETTINGS.panelOpacity, 0.25, 0.85),
      hotbarScale: clamp(Number(parsed.hotbarScale) || DEFAULT_UI_SETTINGS.hotbarScale, 0.75, 1.35),
    };
  } catch {
    return { ...DEFAULT_UI_SETTINGS };
  }
};

export const saveUiSettings = (settings: UiSettings) => {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(settings));
};

/** Push settings into CSS custom properties on :root */
export const applyUiSettings = (settings: UiSettings) => {
  const root = document.documentElement;

  root.style.setProperty('--inv-highlight', resolveHighlightRgb(settings));
  root.style.setProperty('--inv-panel-alpha', String(settings.panelOpacity));
  root.style.setProperty('--inv-hotbar-scale', String(settings.hotbarScale));
};
