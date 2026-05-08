import React from 'react';
import useAppStore from '../stores/appStore';

/**
 * LlmSelector v2
 * Dynamic model dropdown — live fetch dari provider API via RAG proxy.
 * Menampilkan badge 🌐 Live / 📋 Cached dan loading spinner.
 */
export default function LlmSelector() {
  const {
    selectedProvider, selectedModel,
    availableProviders, availableModels,
    setProvider, setModel,
    isFetchingModels, modelFetchSource,
  } = useAppStore();

  return (
    <>
      {/* ── Provider Dropdown ── */}
      <select
        id="llm-provider-select"
        className="glass-select"
        value={selectedProvider}
        onChange={(e) => setProvider(e.target.value)}
        style={{ flex: 1 }}
        title="Pilih AI Provider"
        disabled={isFetchingModels}
      >
        <option value="" disabled>Pilih AI...</option>
        {availableProviders.map(p => (
          <option key={p} value={p}>{p}</option>
        ))}
      </select>

      {/* ── Model Dropdown ── */}
      <div style={{ flex: 1, position: 'relative', display: 'flex', alignItems: 'center' }}>
        <select
          id="llm-model-select"
          className="glass-select"
          value={selectedModel}
          onChange={(e) => setModel(e.target.value)}
          style={{ width: '100%', paddingRight: isFetchingModels ? '2rem' : undefined }}
          title={`Pilih Model (${modelFetchSource === 'live' ? '🌐 Live' : '📋 Cached'})`}
          disabled={isFetchingModels || availableModels.length === 0}
        >
          {isFetchingModels && (
            <option value="" disabled>⏳ Memuat model...</option>
          )}
          {!isFetchingModels && availableModels.length === 0 && (
            <option value="" disabled>— Tidak ada model —</option>
          )}
          {availableModels.map(m => (
            <option key={m} value={m}>{m}</option>
          ))}
        </select>

        {/* Loading spinner saat fetch live */}
        {isFetchingModels && (
          <span
            title="Mengambil daftar model dari provider..."
            style={{
              position: 'absolute',
              right: '0.5rem',
              fontSize: '0.7rem',
              animation: 'spin 1s linear infinite',
              pointerEvents: 'none',
              userSelect: 'none',
            }}
          >
            ⏳
          </span>
        )}
      </div>

      {/* ── Source Badge ── */}
      {selectedProvider && !selectedProvider.includes('Local') && (
        <span
          id="model-source-badge"
          title={modelFetchSource === 'live'
            ? 'Model diambil langsung dari provider API'
            : 'Menggunakan daftar model bawaan (RAG offline atau fetch gagal)'}
          style={{
            fontSize: '0.65rem',
            padding: '0.15rem 0.4rem',
            borderRadius: '0.75rem',
            background: modelFetchSource === 'live'
              ? 'rgba(34,197,94,0.15)'
              : 'rgba(148,163,184,0.15)',
            color: modelFetchSource === 'live' ? '#4ade80' : '#94a3b8',
            border: `1px solid ${modelFetchSource === 'live' ? 'rgba(74,222,128,0.3)' : 'rgba(148,163,184,0.2)'}`,
            whiteSpace: 'nowrap',
            cursor: 'default',
            alignSelf: 'center',
            flexShrink: 0,
          }}
        >
          {modelFetchSource === 'live' ? '🌐 Live' : '📋 Cache'}
        </span>
      )}

      <style>{`
        @keyframes spin { from { transform: rotate(0deg); } to { transform: rotate(360deg); } }
      `}</style>
    </>
  );
}
