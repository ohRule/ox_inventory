import React from 'react';
import { createRoot } from 'react-dom/client';
import { Provider } from 'react-redux';
import { DndProvider } from 'react-dnd';
import { TouchBackend } from 'react-dnd-touch-backend';
import { MantineProvider } from '@mantine/core';
import '@mantine/core/styles.css';
import { store } from './store';
import App from './App';
import './index.scss';
import { ItemNotificationsProvider } from './components/utils/ItemNotifications';
import { isEnvBrowser } from './utils/misc';
import { applyUiSettings, loadUiSettings } from './utils/uiSettings';

const root = document.getElementById('root');

// Restore highlight / opacity / hotbar scale before first paint
applyUiSettings(loadUiSettings());

if (isEnvBrowser()) {
  // https://i.imgur.com/iPTAdYV.png - Night time img
  root!.style.backgroundImage = 'url("https://i.imgur.com/3pzRj9n.png")';
  root!.style.backgroundSize = 'cover';
  root!.style.backgroundRepeat = 'no-repeat';
  root!.style.backgroundPosition = 'center';
}

createRoot(root!).render(
  <React.StrictMode>
    <MantineProvider
      forceColorScheme="dark"
      cssVariablesResolver={() => ({
        variables: {},
        light: { '--mantine-color-body': 'transparent' },
        dark: { '--mantine-color-body': 'transparent' },
      })}
    >
      <Provider store={store}>
        <DndProvider backend={TouchBackend} options={{ enableMouseEvents: true }}>
          <ItemNotificationsProvider>
            <App />
          </ItemNotificationsProvider>
        </DndProvider>
      </Provider>
    </MantineProvider>
  </React.StrictMode>
);
