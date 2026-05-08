import React, { useState } from 'react';
import useAppStore from '../stores/appStore';

export default function DocumentSelector() {
  const { 
    documents, 
    selectedDocIds, 
    toggleDocument, 
    clearDocuments, 
    selectedCategory, 
    setCategory 
  } = useAppStore();
  const [isOpen, setIsOpen] = useState(false);

  if (documents.length === 0) {
    return (
      <div className="tag tag-info" style={{ fontSize: 11, cursor: 'default' }}>
        No docs
      </div>
    );
  }

  // Extract unique categories
  const categories = ['Semua Kategori', ...new Set(documents.map(d => d.variable || d.category || 'Uncategorized'))];

  // Filter documents
  const filteredDocs = selectedCategory === 'Semua Kategori'
    ? documents
    : documents.filter(d => (d.variable || d.category || 'Uncategorized') === selectedCategory);

  return (
    <div style={{ position: 'relative' }}>
      <button
        className="btn-ghost"
        onClick={() => setIsOpen(!isOpen)}
        style={{ display: 'flex', alignItems: 'center', gap: 4 }}
      >
        📄 {selectedDocIds.length > 0 ? `${selectedDocIds.length} doc` : 'Pilih doc'}
        <span style={{ fontSize: 10, opacity: 0.6 }}>▼</span>
      </button>

      {isOpen && (
        <div
          className="glass-card elevated"
          style={{
            position: 'absolute',
            top: '100%',
            right: 0,
            width: 280,
            padding: '12px',
            zIndex: 100,
            maxHeight: 350,
            overflowY: 'auto',
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 12 }}>
            <span style={{ fontSize: 11, fontWeight: 700 }}>Sumber Penelitian</span>
            {selectedDocIds.length > 0 && (
              <button className="btn-ghost" style={{ fontSize: 10, padding: '2px 6px', color: 'var(--primary)' }} onClick={clearDocuments}>
                Clear
              </button>
            )}
          </div>

          {/* Category Filter */}
          <div style={{ marginBottom: 14 }}>
            <div style={{ fontSize: 10, color: 'var(--text-secondary)', marginBottom: 6, fontWeight: 600 }}>FILTER KATEGORI</div>
            <select 
              value={selectedCategory}
              onChange={(e) => setCategory(e.target.value)}
              className="glass-select"
              style={{
                width: '100%',
                padding: '6px 10px',
                fontSize: 11,
                borderRadius: 8,
                background: 'rgba(255,255,255,0.05)',
                border: '1px solid rgba(255,255,255,0.1)',
                color: 'var(--text-primary)',
                outline: 'none',
                cursor: 'pointer'
              }}
            >
              {categories.map(cat => (
                <option key={cat} value={cat} style={{ background: '#fff', color: '#333' }}>{cat}</option>
              ))}
            </select>
          </div>

          <div style={{ fontSize: 10, color: 'var(--text-secondary)', marginBottom: 8, fontWeight: 600 }}>
            DAFTAR DOKUMEN ({filteredDocs.length})
          </div>

          {filteredDocs.length === 0 ? (
            <div style={{ fontSize: 11, color: 'var(--text-secondary)', padding: '10px 0', textAlign: 'center', fontStyle: 'italic' }}>
              Tidak ada dokumen di kategori ini
            </div>
          ) : (
            filteredDocs.map(doc => {
              const isSelected = selectedDocIds.includes(doc.id);
              return (
                <div
                  key={doc.id}
                  onClick={() => toggleDocument(doc.id)}
                  style={{
                    padding: '10px 12px',
                    borderRadius: 10,
                    cursor: 'pointer',
                    background: isSelected ? 'rgba(229, 57, 53, 0.08)' : 'rgba(255, 255, 255, 0.03)',
                    border: isSelected ? '1px solid rgba(229, 57, 53, 0.2)' : '1px solid rgba(255,255,255,0.05)',
                    marginBottom: 6,
                    transition: 'all 0.15s',
                  }}
                >
                  <div style={{ fontSize: 12, fontWeight: 600, lineHeight: 1.4, color: isSelected ? 'var(--primary)' : 'inherit' }}>
                    {isSelected && '✓ '}{doc.title}
                  </div>
                  <div style={{ fontSize: 10, color: 'var(--text-secondary)', marginTop: 4, display: 'flex', justifyContent: 'space-between' }}>
                    <span>{doc.authors?.slice(0, 1).join(', ')} et al. · {doc.year || 'n/a'}</span>
                    <span style={{ fontSize: 9, opacity: 0.7, background: 'rgba(0,0,0,0.1)', padding: '1px 4px', borderRadius: 4 }}>
                      {doc.variable || doc.category || 'n/a'}
                    </span>
                  </div>
                </div>
              );
            })
          )}
        </div>
      )}
    </div>
  );
}
