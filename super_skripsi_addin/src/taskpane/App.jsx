import React, { useEffect, useState } from 'react';
import useAppStore from './stores/appStore';
import ChatPanel from './components/ChatPanel';
import ParafrasePanel from './components/ParafrasePanel';
import LlmSelector from './components/LlmSelector';
import DocumentSelector from './components/DocumentSelector';
import { isRagServiceAvailable } from './services/ragBridge';

export default function App() {
  const { initialize, isConnected, refreshConnection } = useAppStore();
  const [activePage, setActivePage] = useState('sitasi');
  const [ragMode, setRagMode] = useState('checking'); // 'checking' | 'semantic' | 'tfidf'

  useEffect(() => {
    initialize();
    // Refresh Manager connection every 10 seconds
    const interval = setInterval(refreshConnection, 10000);
    return () => clearInterval(interval);
  }, []);

  // Periksa status Python RAG service saat startup dan setiap 20 detik
  useEffect(() => {
    const checkRag = async () => {
      const available = await isRagServiceAvailable();
      setRagMode(available ? 'semantic' : 'tfidf');
    };

    checkRag();
    const ragInterval = setInterval(checkRag, 20000);
    return () => clearInterval(ragInterval);
  }, []);

  const ragBadgeConfig = {
    checking: { label: '🔍 Checking', cls: 'rag-checking' },
    semantic:  { label: '🧠 Semantic', cls: 'rag-semantic' },
    tfidf:     { label: '📊 TF-IDF',  cls: 'rag-tfidf' },
  };

  const badge = ragBadgeConfig[ragMode];

  return (
    <div className="app-container">
      {/* Header */}
      <header className="app-header">
        <div className="logo-section">
          <img src="assets/icon-32.png" className="logo-icon-img" alt="Logo" />
          <div className="title-wrapper">
            <span className="logo-text">Super Skripsi</span>
            <span className="version-tag">v1.1.11</span>
          </div>
        </div>
        <div className="header-badges">
          {/* RAG Status Badge */}
          <div
            className={`rag-badge ${badge.cls}`}
            title={
              ragMode === 'semantic'
                ? 'Python RAG aktif — Semantic Search (ChromaDB + SentenceTransformers)'
                : ragMode === 'tfidf'
                  ? 'Python RAG tidak aktif — menggunakan TF-IDF (keyword search)'
                  : 'Memeriksa status RAG...'
            }
          >
            <span className="rag-dot" />
            <span>{badge.label}</span>
          </div>
          {/* Manager Connection Badge */}
          <div className={`connection-badge ${isConnected ? 'connected' : 'disconnected'}`}>
            <span className="connection-dot"></span>
            {isConnected ? 'Manager' : 'Offline'}
          </div>
        </div>
      </header>

      {/* Tab Bar */}
      <div className="tab-bar">
        <button
          className={`tab-item ${activePage === 'sitasi' ? 'active' : ''}`}
          onClick={() => setActivePage('sitasi')}
        >
          <span className="tab-icon">🎓</span>
          <span>Sitasi</span>
        </button>
        <button
          className={`tab-item ${activePage === 'parafrase' ? 'active' : ''}`}
          onClick={() => setActivePage('parafrase')}
        >
          <span className="tab-icon">✍️</span>
          <span>Parafrase</span>
        </button>
      </div>

      {/* Config Bar — only for Sitasi page */}
      {activePage === 'sitasi' && (
        <div className="config-bar">
          <LlmSelector />
          <DocumentSelector />
        </div>
      )}

      {/* Main Content */}
      {activePage === 'sitasi' ? <ChatPanel /> : <ParafrasePanel />}
    </div>
  );
}
