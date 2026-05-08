import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './styles/glassmorphism.css';
import './styles/index.css';

/* global Office */

Office.onReady((info) => {
  if (info.host === Office.HostType.Word || !info.host) {
    const root = createRoot(document.getElementById('root'));
    root.render(<App />);
  }
});
