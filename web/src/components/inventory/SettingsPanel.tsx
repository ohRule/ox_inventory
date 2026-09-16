import React, { useMemo, useState } from 'react';
import { ColorPicker, TextInput } from '@mantine/core';
import {
  applyUiSettings,
  DEFAULT_UI_SETTINGS,
  HIGHLIGHT_PRESETS,
  HighlightId,
  loadUiSettings,
  normaliseHex,
  saveUiSettings,
  UiSettings,
} from '../../utils/uiSettings';

type PresetId = Exclude<HighlightId, 'custom'>;

const PRESET_SWATCHES = (Object.keys(HIGHLIGHT_PRESETS) as PresetId[]).map(
  (id) => HIGHLIGHT_PRESETS[id].hex
);

const formatOpacity = (value: number) => `${Math.round(value * 100)}%`;
const formatScale = (value: number) => `${Math.round(value * 100)}%`;

const presetIdFromHex = (hex: string): PresetId | null => {
  const normalised = normaliseHex(hex);
  if (!normalised) return null;
  for (const id of Object.keys(HIGHLIGHT_PRESETS) as PresetId[]) {
    if (HIGHLIGHT_PRESETS[id].hex === normalised) return id;
  }
  return null;
};

/** Persisted UI prefs: highlight colour, panel opacity, hotbar scale */
const SettingsPanel: React.FC = () => {
  const [settings, setSettings] = useState<UiSettings>(() => loadUiSettings());

  const highlightValue = useMemo(() => {
    if (settings.highlight === 'custom') return settings.customHighlight;
    return HIGHLIGHT_PRESETS[settings.highlight as PresetId]?.hex ?? settings.customHighlight;
  }, [settings.highlight, settings.customHighlight]);

  const update = (patch: Partial<UiSettings>) => {
    setSettings((prev) => {
      const next = { ...prev, ...patch };
      saveUiSettings(next);
      applyUiSettings(next);
      return next;
    });
  };

  const applyHighlight = (hex: string) => {
    const normalised = normaliseHex(hex);
    if (!normalised) return;

    const preset = presetIdFromHex(normalised);
    if (preset) {
      update({ highlight: preset, customHighlight: normalised });
      return;
    }

    update({ highlight: 'custom', customHighlight: normalised });
  };

  const reset = () => {
    saveUiSettings(DEFAULT_UI_SETTINGS);
    applyUiSettings(DEFAULT_UI_SETTINGS);
    setSettings({ ...DEFAULT_UI_SETTINGS });
  };

  return (
    <div className="inventory-side-panel settings-panel">
      <div className="settings-section">
        <p className="settings-label">Highlight colour</p>
        <ColorPicker
          className="settings-color-picker"
          format="hex"
          fullWidth
          size="sm"
          swatchesPerRow={6}
          swatches={PRESET_SWATCHES}
          value={highlightValue}
          onChange={applyHighlight}
          saturationLabel="Saturation"
          hueLabel="Hue"
        />
        <TextInput
          className="settings-hex-mantine"
          size="xs"
          value={highlightValue}
          spellCheck={false}
          maxLength={7}
          aria-label="Custom highlight hex"
          onChange={(event) => applyHighlight(event.currentTarget.value)}
        />
      </div>

      <div className="settings-section">
        <div className="settings-label-row">
          <p className="settings-label">Panel opacity</p>
          <span className="settings-value">{formatOpacity(settings.panelOpacity)}</span>
        </div>
        <input
          className="settings-slider"
          type="range"
          min={0.25}
          max={0.85}
          step={0.05}
          value={settings.panelOpacity}
          onChange={(event) => update({ panelOpacity: Number(event.target.value) })}
          aria-label="Panel opacity"
        />
      </div>

      <div className="settings-section">
        <div className="settings-label-row">
          <p className="settings-label">Hotbar scale</p>
          <span className="settings-value">{formatScale(settings.hotbarScale)}</span>
        </div>
        <input
          className="settings-slider"
          type="range"
          min={0.75}
          max={1.35}
          step={0.05}
          value={settings.hotbarScale}
          onChange={(event) => update({ hotbarScale: Number(event.target.value) })}
          aria-label="Hotbar scale"
        />
      </div>

      <button type="button" className="settings-reset" onClick={reset}>
        Reset to defaults
      </button>
    </div>
  );
};

export default SettingsPanel;
