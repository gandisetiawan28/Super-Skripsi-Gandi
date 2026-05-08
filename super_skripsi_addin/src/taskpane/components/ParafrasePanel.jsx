import React, { useState, useRef } from 'react';
import useAppStore from '../stores/appStore';
import { getSelectedText, insertFormattedText, sanitizeHtmlTags } from '../services/wordInjector';
import { sendToLLM } from '../services/llmRouter';
import { STYLES, FORMATS, LANGUAGES, buildParafrasePrompt } from '../services/parafrasePrompt';

export default function ParafrasePanel() {
  const { selectedProvider, selectedModel, availableProviders, availableModels, setProvider, setModel, apiKeys } = useAppStore();

  const [inputText, setInputText] = useState('');
  const [style, setStyle] = useState('humanis');
  const [format, setFormat] = useState('deskripsi');
  const [language, setLanguage] = useState('id');
  const [result, setResult] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [status, setStatus] = useState('');
  const [error, setError] = useState('');
  
  const abortControllerRef = useRef(null);

  // ── Auto-capture selection ──
  React.useEffect(() => {
    /* global Office */
    const onSelectionChanged = async () => {
      try {
        const text = await getSelectedText();
        if (text && text.trim().length > 0) {
          setInputText(text);
          setError('');
        }
      } catch (e) {
        console.warn('Failed to auto-capture selection:', e);
      }
    };

    // Register handler
    Office.context.document.addHandlerAsync(
      Office.EventType.DocumentSelectionChanged,
      onSelectionChanged
    );

    // Initial check
    onSelectionChanged();

    return () => {
      // Cleanup handler
      Office.context.document.removeHandlerAsync(
        Office.EventType.DocumentSelectionChanged,
        { handler: onSelectionChanged }
      );
    };
  }, []);

  const handleGrabText = async () => {
    try {
      setStatus('📋 Membaca teks yang diblok...');
      const text = await getSelectedText();
      if (text.trim()) {
        setInputText(text);
        setStatus('');
        setError('');
      } else {
        setError('Tidak ada teks yang diblok di Word. Silakan blok/highlight teks terlebih dahulu.');
        setStatus('');
      }
    } catch (e) {
      setError('Gagal membaca teks dari Word: ' + e.message);
      setStatus('');
    }
  };

  const handleParafrase = async () => {
    if (!inputText.trim() || !selectedProvider) return;

    setIsLoading(true);
    setResult('');
    setError('');

    try {
      setStatus('🧠 Membangun prompt parafrase...');
      const prompt = buildParafrasePrompt({ text: inputText, style, format, language });
      
      setStatus('🚀 Menghubungi AI...');
      const keys = apiKeys[selectedProvider] || [];
      const controller = new AbortController();
      abortControllerRef.current = controller;

      const response = await sendToLLM({
        provider: selectedProvider,
        model: selectedModel,
        messages: [
          { role: 'system', content: 'Kamu adalah pakar parafrase akademik. Ikuti semua instruksi dengan ketat.' },
          { role: 'user', content: prompt },
        ],
        apiKeys: Array.isArray(keys) ? keys : [keys],
        signal: controller.signal,
        onStatusUpdate: (s) => setStatus(s),
      });

      // Sanitize AI response to fix unclosed tags BEFORE displaying in UI
      setResult(sanitizeHtmlTags(response));
      setStatus('');
    } catch (e) {
      if (e.name === 'AbortError' || e.message === 'AbortError') {
        setStatus('🛑 Proses dibatalkan oleh pengguna.');
        setTimeout(() => setStatus(''), 3000);
      } else {
        setError('Error: ' + e.message);
        setStatus('');
      }
    } finally {
      setIsLoading(false);
      abortControllerRef.current = null;
    }
  };

  const handleCancel = () => {
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
  };

  const handleUseResult = async () => {
    if (!result) return;
    try {
      await insertFormattedText(result);
      setStatus('✅ Teks berhasil dimasukkan ke Word!');
      setTimeout(() => setStatus(''), 3000);
    } catch (e) {
      setError('Gagal memasukkan teks: ' + e.message);
    }
  };

  const handleCopyResult = () => {
    navigator.clipboard.writeText(result);
    setStatus('📋 Disalin ke clipboard!');
    setTimeout(() => setStatus(''), 2000);
  };

  return (
    <div className="parafrase-container">
      {/* Input Area (Auto-populated from Word selection) */}
      <div className="parafrase-section">
        <label className="section-label">TEKS ASLI (Otomatis dari Word)</label>
        <textarea
          className="parafrase-input"
          value={inputText}
          onChange={(e) => setInputText(e.target.value)}
          placeholder="Blok teks di Word untuk mengisi otomatis..."
          rows={5}
          disabled={isLoading}
        />
        {inputText && (
          <div className="char-count">{inputText.length} karakter · {inputText.split(/\s+/).filter(Boolean).length} kata</div>
        )}
      </div>

      {/* Config Grid */}
      <div className="parafrase-section">
        <div className="config-grid">
          {/* AI Provider */}
          <div className="config-item">
            <label className="section-label">🤖 AI PROVIDER</label>
            <select className="glass-select compact" value={selectedProvider} onChange={(e) => setProvider(e.target.value)}>
              <option value="" disabled>Pilih AI...</option>
              {availableProviders.map(p => <option key={p} value={p}>{p}</option>)}
            </select>
          </div>

          {/* Model */}
          <div className="config-item">
            <label className="section-label">📦 MODEL</label>
            <select className="glass-select compact" value={selectedModel} onChange={(e) => setModel(e.target.value)}>
              {availableModels.map(m => <option key={m} value={m}>{m}</option>)}
            </select>
          </div>

          {/* Style */}
          <div className="config-item">
            <label className="section-label">✍️ GAYA</label>
            <select className="glass-select compact" value={style} onChange={(e) => setStyle(e.target.value)}>
              {Object.entries(STYLES).map(([key, val]) => (
                <option key={key} value={key}>{val.label}</option>
              ))}
            </select>
          </div>

          {/* Format */}
          <div className="config-item">
            <label className="section-label">📋 FORMAT</label>
            <select className="glass-select compact" value={format} onChange={(e) => setFormat(e.target.value)}>
              {Object.entries(FORMATS).map(([key, val]) => (
                <option key={key} value={key}>{val.label}</option>
              ))}
            </select>
          </div>

          {/* Language */}
          <div className="config-item full-width">
            <label className="section-label">🌐 BAHASA</label>
            <select className="glass-select compact" value={language} onChange={(e) => setLanguage(e.target.value)}>
              {Object.entries(LANGUAGES).map(([key, val]) => (
                <option key={key} value={key}>{val.label}</option>
              ))}
            </select>
          </div>
        </div>
      </div>

      {/* Parafrase & Stop Buttons */}
      <div style={{ display: 'flex', gap: '8px' }}>
        <button 
          className="btn-primary parafrase-btn"
          onClick={handleParafrase} 
          disabled={isLoading || !inputText.trim() || !selectedProvider}
          style={{ flex: 1 }}
        >
          {isLoading ? (
            <><div className="spinner"></div> Memproses...</>
          ) : (
            <>✨ Parafrase Sekarang</>
          )}
        </button>

        {isLoading && (
          <button 
            className="btn-primary"
            onClick={handleCancel}
            style={{ backgroundColor: '#ef4444', padding: '0 1rem' }}
            title="Batalkan proses"
          >
            🛑
          </button>
        )}
      </div>

      {/* Status */}
      {status && (
        <div className="parafrase-status animate-in">
          {status}
        </div>
      )}

      {/* Error */}
      {error && (
        <div className="parafrase-error animate-in">
          ❌ {error}
        </div>
      )}

      {/* Result */}
      {result && (
        <div className="parafrase-section animate-in">
          <label className="section-label" style={{ color: 'var(--success)' }}>✅ HASIL PARAFRASE</label>
          <div 
            className="parafrase-result-preview" 
            dangerouslySetInnerHTML={{ __html: result }}
          />
          <div className="result-actions">
            <button className="btn-use" onClick={handleUseResult}>
              📝 Gunakan di Word
            </button>
            <button className="btn-ghost" onClick={handleCopyResult} style={{ fontSize: 11 }}>
              📋 Salin
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
