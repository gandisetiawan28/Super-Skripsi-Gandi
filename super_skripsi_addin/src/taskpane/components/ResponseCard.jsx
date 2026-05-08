import React from 'react';
import { insertAcademicText, insertVerbatimQuote } from '../services/wordInjector';
import useAppStore from '../stores/appStore';

export default function ResponseCard({ option, index, messageId }) {
  const { startParaphrase, isLoading } = useAppStore();

  const handleUseParaphrase = async () => {
    try {
      await insertAcademicText({
        paraphrase: option.paraphrase,
        citation: '', 
      });
    } catch (e) {
      console.error('Insert error:', e);
    }
  };

  const handleUseVerbatim = async () => {
    try {
      await insertVerbatimQuote({
        verbatim: option.verbatim,
        citation: option.citation,
      });
    } catch (e) {
      console.error('Insert error:', e);
    }
  };

  const handleInsertBibliography = async () => {
    try {
      await insertAcademicText({
        paraphrase: option.bibliography,
        citation: '',
      });
    } catch (e) {
      console.error('Insert bib error:', e);
    }
  };

  const handleStartParaphrase = () => {
    startParaphrase(messageId, index);
  };

  return (
    <div className="glass-card response-card animate-in" style={{ animationDelay: `${index * 0.1}s` }}>
      <div className="card-header">
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span className="option-number">{index + 1}</span>
          <span style={{ fontSize: 12, fontWeight: 600 }}>Kutipan {index + 1}</span>
        </div>
        {option.citation && (
          <span style={{ fontSize: 10, color: 'var(--text-secondary)' }}>{option.citation}</span>
        )}
      </div>

      {/* Verbatim */}
      <div className="response-section">
        <div className="response-label verbatim">
          📖 Kutipan Asli (Verbatim)
        </div>
        <div className="response-text verbatim-text" dangerouslySetInnerHTML={{ 
          __html: `"${option.verbatim}"` 
        }} />
        <button className="btn-ghost" style={{ marginTop: 4, fontSize: 11 }} onClick={handleUseVerbatim}>
          ↳ Sisipkan Kutipan
        </button>
      </div>

      {/* Paraphrase */}
      <div className="response-section" style={{ borderTop: '1px solid rgba(255,255,255,0.05)', paddingTop: 12 }}>
        <div className="response-label paraphrase">
          ✍️ Hasil Parafrase:
        </div>
        
        {option.isPending ? (
          <div className="pending-paraphrase" style={{ padding: '8px 0' }}>
            <button 
              className="btn-primary" 
              onClick={handleStartParaphrase}
              disabled={isLoading}
              style={{ width: '100%', fontSize: 12, padding: '8px' }}
            >
              {isLoading ? '⏳ Memproses...' : '✨ Mulai Parafrase'}
            </button>
            <p style={{ fontSize: 10, color: 'var(--text-secondary)', marginTop: 8, textAlign: 'center' }}>
              Klik tombol di atas untuk menyusun parafrase akademik.
            </p>
          </div>
        ) : (
          <>
            <div className="response-text paraphrase-text" dangerouslySetInnerHTML={{ 
              __html: option.paraphrase
                ? option.paraphrase.replace(/\*\*([^\*]+)\*\*/g, '<b>$1</b>').replace(/\*([^\*]+)\*/g, '<i>$1</i>').replace(/_([^_]+)_/g, '<i>$1</i>')
                : ''
            }} />
            <button className="btn-use" style={{ width: '100%', marginTop: 8 }} onClick={handleUseParaphrase}>
              ✨ Gunakan Parafrase Ini
            </button>
          </>
        )}
      </div>

      {/* Bibliography */}
      {!option.isPending && option.bibliography && (
        <div className="response-section" style={{ marginTop: 12, borderTop: '1px solid rgba(255,255,255,0.1)', paddingTop: 12 }}>
          <div className="response-label citation">
            📚 Daftar Pustaka:
          </div>
          <div className="response-text bibliography-text" style={{ fontStyle: 'italic', fontSize: 11 }} dangerouslySetInnerHTML={{ 
            __html: option.bibliography 
          }} />
          <button className="btn-ghost" style={{ marginTop: 4, fontSize: 11 }} onClick={handleInsertBibliography}>
            ↳ Tambah ke Daftar Pustaka
          </button>
        </div>
      )}
    </div>
  );
}
