import React, { useRef, useEffect, useState } from 'react';
import useAppStore from '../stores/appStore';
import ResponseCard from './ResponseCard';

export default function ChatPanel() {
  const { messages, isLoading, thinkingStatus, sendMessage, stopGeneration, clearChat, selectedProvider } = useAppStore();
  const [input, setInput] = useState('');
  const chatEndRef = useRef(null);
  const textareaRef = useRef(null);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isLoading]);

  const handleSend = () => {
    if (input.trim() && !isLoading) {
      sendMessage(input.trim());
      setInput('');
      if (textareaRef.current) {
        textareaRef.current.style.height = '38px';
      }
    }
  };

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleInput = (e) => {
    setInput(e.target.value);
    // Auto-resize textarea
    e.target.style.height = '38px';
    e.target.style.height = Math.min(e.target.scrollHeight, 100) + 'px';
  };

  return (
    <>
      {/* Chat Area */}
      <div className="chat-area">
        {messages.length === 0 && !isLoading ? (
          <div className="chat-empty">
            <div className="empty-icon">🎓</div>
            <h3>Super Skripsi Gandi</h3>
            <p>
              Tanyakan apapun dari dokumen penelitian Anda.
              AI akan memberikan kutipan asli, parafrase, dan sitasi APA secara otomatis.
            </p>
            {!selectedProvider && (
              <p style={{ color: 'var(--error)', marginTop: 8, fontSize: 11 }}>
                ⚠️ Pilih AI provider terlebih dahulu
              </p>
            )}
          </div>
        ) : (
          <>
            {messages.map((msg, i) => {
              if (msg.role === 'user') {
                return (
                  <div key={i} className="message-user">
                    {msg.content}
                  </div>
                );
              }

              // AI response
              if (msg.isError) {
                return (
                  <div key={i} className="glass-card animate-in" style={{
                    padding: 12,
                    border: '1px solid rgba(229,57,53,0.2)',
                    background: 'rgba(229,57,53,0.05)',
                  }}>
                    <span style={{ color: 'var(--error)', fontSize: 13 }}>
                      ❌ {msg.content}
                    </span>
                  </div>
                );
              }

              if (msg.options && msg.options.length > 0) {
                return (
                  <div key={i} className="message-ai">
                    <div className="response-cards">
                      {msg.options.map((opt, j) => (
                        <ResponseCard key={j} option={opt} index={j} messageId={msg.id} />
                      ))}
                    </div>
                  </div>
                );
              }

              // Fallback plain text
              return (
                <div key={i} className="glass-card animate-in" style={{ padding: 12 }}>
                  <span style={{ fontSize: 13 }}>{msg.content}</span>
                </div>
              );
            })}

            {isLoading && (
              <div className="message-loading" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 6 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <div className="spinner"></div>
                  <span style={{ fontWeight: 600 }}>AI sedang berpikir...</span>
                </div>
                {thinkingStatus && (
                  <div className="thinking-log" style={{ 
                    fontSize: 11, 
                    color: 'var(--text-secondary)', 
                    background: 'rgba(255,255,255,0.05)',
                    padding: '4px 8px',
                    borderRadius: 4,
                    fontFamily: 'monospace',
                    animation: 'pulse 2s infinite'
                  }}>
                    {thinkingStatus}
                  </div>
                )}
              </div>
            )}
          </>
        )}
        <div ref={chatEndRef} />
      </div>

      {/* Input Bar */}
      <div className="input-bar">
        {(messages.length > 0 || isLoading) && (
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
            {isLoading ? (
              <button 
                className="btn-stop animate-pulse" 
                onClick={stopGeneration}
                style={{ 
                  background: 'rgba(229,57,53,0.15)',
                  color: '#ff5252',
                  border: '1px solid rgba(229,57,53,0.3)',
                  padding: '4px 12px',
                  borderRadius: '12px',
                  fontSize: '11px',
                  fontWeight: '700',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  boxShadow: '0 0 15px rgba(229,57,53,0.1)'
                }}
              >
                <div style={{ width: 8, height: 8, background: '#ff5252', borderRadius: '1px' }}></div>
                STOP GENERATION
              </button>
            ) : <div />}
            
            {messages.length > 0 && (
              <button className="btn-ghost" style={{ fontSize: 11 }} onClick={clearChat}>
                🗑 Clear chat
              </button>
            )}
          </div>
        )}
        <div className="input-wrapper">
          <textarea
            ref={textareaRef}
            value={input}
            onChange={handleInput}
            onKeyDown={handleKeyDown}
            placeholder="Tanyakan sesuatu dari jurnal..."
            rows={1}
            disabled={isLoading || !selectedProvider}
          />
          <button
            className="send-btn"
            onClick={handleSend}
            disabled={isLoading || !input.trim() || !selectedProvider}
            title="Kirim"
          >
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <line x1="22" y1="2" x2="11" y2="13" />
              <polygon points="22 2 15 22 11 13 2 9 22 2" />
            </svg>
          </button>
        </div>
      </div>
    </>
  );
}
