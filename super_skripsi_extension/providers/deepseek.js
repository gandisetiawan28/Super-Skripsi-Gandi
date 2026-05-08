/* =============================================
   AI Auto-Flow — DeepSeek Provider
   ============================================= */

class DeepSeekProvider extends BaseProvider {
  constructor() {
    super();
    this.PATH_SEND = "M8.3125 0.981587C8.66767 1.0545 8.97902 1.20558 9.2627 1.43374C9.48724 1.61438 9.73029 1.85933 9.97949 2.10854L14.707 6.83608L13.293 8.25014L9 3.95717V15.0431H7V3.95717L2.70703 8.25014L1.29297 6.83608L6.02051 2.10854C6.26971 1.85933 6.51277 1.61438 6.7373 1.43374C6.97662 1.24126 7.28445 1.04542 7.6875 0.981587C7.8973 0.94841 8.1031 0.956564 8.3125 0.981587Z";
    this.PATH_STOP = "M2 4.88C2 3.68009 2 3.08013 2.30557 2.65954C2.40426 2.52371 2.52371 2.40426 2.65954 2.30557C3.08013 2 3.68009 2 4.88 2H11.12C12.3199 2 12.9199 2 13.3405 2.30557C13.4763 2.40426 13.5957 2.52371 13.6944 2.65954C14 3.08013 14 3.68009 14 4.88V11.12C14 12.3199 14 12.9199 13.6944 13.3405C13.5957 13.4763 13.4763 13.5957 13.3405 13.6944C12.9199 14 12.3199 14 11.12 14H4.88C3.68009 14 3.08013 14 2.65954 13.6944C2.52371 13.5957 2.40426 13.4763 2.30557 13.3405C2 12.9199 2 12.3199 2 11.12V4.88Z";
    
    this.SELECTORS = {
      input: [
        'textarea[placeholder*="DeepSeek"]',
        'textarea[placeholder*="Pesan"]',
        'textarea[placeholder*="Message"]',
        '#chat-input',
      ],
      response: ['.ds-markdown', '.ds-message-content--ai']
    };
    this.lastContinueClick = 0;
    this.stabilityThreshold = 5; // 5 * 200ms = 1.0s buffer
  }

  findInput() {
    // Mencari textarea di dalam area pengetikan utama DeepSeek
    const composer = document.querySelector('.ds-composer-input, .ds-textarea-wrapper');
    if (composer) {
      const input = composer.querySelector('textarea');
      if (input) return input;
    }
    
    // Fallback: cari textarea yang paling besar atau punya autofocus
    return document.querySelector('textarea[autofocus]') || this.utils.findElement(this.SELECTORS.input);
  }

  findStopButton() {
    // 1. Cari di area composer (paling akurat)
    const composer = document.querySelector('.ds-composer-send-button-container, [class*="send-button"]');
    if (composer) {
      const btn = composer.querySelector('button, div[role="button"]');
      // Jika tombol ada tapi bukan tombol send (biasanya ikonnya berubah jadi kotak stop)
      if (btn && (btn.querySelector('rect') || btn.querySelector('svg'))) {
         return btn;
      }
    }

    // 2. Cari global berdasarkan atribut dan ikon
    const buttons = document.querySelectorAll('button, div[role="button"], div[class*="ds-icon-button"]');
    for (const btn of buttons) {
      if (btn.offsetParent === null) continue;

      const svg = btn.querySelector('svg');
      if (svg) {
        // Cek jika ada elemen RECT (kotak) di dalam SVG
        if (svg.querySelector('rect')) return btn;
        
        const path = svg.querySelector('path');
        const d = path ? path.getAttribute('d') || '' : '';
        // Tambahkan variasi path kotak stop DeepSeek yang baru
        if (d.startsWith('M2') || d.startsWith('M3') || d.includes('H14V14H2') || d.includes('M4 4h8v8H4z') || d.includes('M6 6h12v12H6z')) return btn;
      }
      
      const ariaLabel = btn.getAttribute('aria-label');
      if (ariaLabel && (ariaLabel.toLowerCase().includes('stop') || ariaLabel.toLowerCase().includes('berhenti') || ariaLabel.toLowerCase().includes('halt'))) return btn;
    }
    return null;
  }

  findSendButton() {
    // 1. Cek kontainer standar
    const composer = document.querySelector('.ds-composer-send-button-container, [class*="send-button"]');
    if (composer) {
      const btn = composer.querySelector('button, div[role="button"]');
      if (btn && !btn.hasAttribute('disabled') && !btn.classList.contains('ds-icon-button--disabled')) {
        return btn;
      }
    }

    // 2. Cari berdasarkan ikon panah (Kirim)
    const buttons = document.querySelectorAll('button:not([disabled]), div[role="button"]:not([disabled])');
    for (const b of buttons) {
      if (b.offsetParent === null) continue;

      const path = b.querySelector('svg path');
      if (path) {
        const d = path.getAttribute('d') || '';
        // Ikon panah DeepSeek biasanya dimulai dengan M8 atau M7
        if (d.startsWith('M8') || d.startsWith('M7') || d.includes('M12 2l9 20-9-4-9 4Z')) {
           // Pastikan bukan tombol stop
           if (!b.querySelector('rect') && !d.includes('H14V14H2')) return b;
        }
      }

      const ariaLabel = b.getAttribute('aria-label');
      if (ariaLabel && (ariaLabel.toLowerCase().includes('send') || ariaLabel.toLowerCase().includes('kirim'))) return b;
    }
    return null;
  }

  findContinueButton() {
    const candidates = document.querySelectorAll('button, div[role="button"], span, div[class*="ds-button"], [data-testid*="continue"]');
    for (const el of candidates) {
      if (el.offsetParent === null) continue;
      
      const text = el.innerText.trim();
      if (!text || text.length > 40) continue;
      
      const lowerText = text.toLowerCase();
      const isContinue = (lowerText.includes('continue') || lowerText.includes('lanjutkan') || lowerText.includes('keep writing')) && 
                         !lowerText.includes('coba lagi') && 
                         !lowerText.includes('regenerate');

      if (isContinue || el.getAttribute('data-testid') === 'continue-button') {
        return el;
      }
    }
    return null;
  }

  isAIGenerating() {
    if (this.findStopButton()) return true;
    if (this.findContinueButton()) return true; // Wajib: Anggap sedang "generating" jika tombol Continue muncul
    
    // Cek indikator visual tambahan
    const indicators = document.querySelectorAll('.ds-loading, .ds-thinking, .ds-cursor, .ds-icon-loading, [class*="thinking"], [class*="loading-bar"]');
    for (const el of indicators) {
      if (el.offsetParent !== null) {
        const style = window.getComputedStyle(el);
        if (style.opacity !== '0' && style.visibility !== 'hidden' && el.getClientRects().length > 0) {
          return true;
        }
      }
    }

    // Jika ada tombol stop tapi findStopButton gagal (selector sangat spesifik), 
    // kita cek apakah tombol send TIDAK ADA/DISABLED saat ada aktivitas
    if (!this.findSendButton() && document.querySelector('.ds-composer-input')) return true;

    return false;
  }

  handleAutoFlow() {
    const continueBtn = this.findContinueButton();
    if (continueBtn) {
      const now = Date.now();
      // Kurangi delay agar lebih responsif (1.5 detik)
      if (now - this.lastContinueClick > 1500) {
        console.log('[DeepSeek] Wajib klik Continue... Menghindari penghentian prematur.');
        this.lastContinueClick = now;
        this.utils.robustClick(continueBtn);
      }
    }
  }

  stopGeneration() {
    const stopBtn = this.findStopButton();
    if (stopBtn) {
      console.log('[DeepSeek] Clicking stop button...');
      this.utils.robustClick(stopBtn);
      return true;
    }
    return false;
  }

  async typeAndSend(text) {
    const inputEl = this.findInput();
    if (!inputEl) {
      console.error('[DeepSeek] Input area not found!');
      throw new Error('Cannot find DeepSeek input area');
    }

    inputEl.focus();
    await this.utils.sleep(500);
    
    console.log('[DeepSeek] Injecting text...');
    this.utils.setReactValue(inputEl, text);
    await this.utils.sleep(500);

    inputEl.dispatchEvent(new Event('input', { bubbles: true }));
    inputEl.dispatchEvent(new Event('change', { bubbles: true }));
    await this.utils.sleep(300);
    
    // Attempt 1: Press Enter
    console.log('[DeepSeek] Attempting to send via Enter key...');
    const enterOpts = { key: 'Enter', code: 'Enter', keyCode: 13, Arabian: 13, bubbles: true };
    inputEl.dispatchEvent(new KeyboardEvent('keydown', enterOpts));
    inputEl.dispatchEvent(new KeyboardEvent('keyup', enterOpts));
    
    // Wait and check if it started generating
    for (let i = 0; i < 10; i++) {
      await this.utils.sleep(500);
      if (this.isAIGenerating()) {
        console.log('[DeepSeek] Generation started successfully.');
        return;
      }
      
      // Attempt 2: Click Send Button if Enter failed
      const sendBtn = this.findSendButton();
      if (sendBtn) {
        console.log('[DeepSeek] Enter failed, clicking Send button (attempt ' + (i+1) + ')...');
        this.utils.robustClick(sendBtn);
      }
    }
    
    throw new Error('Failed to send prompt to DeepSeek (Generation did not start)');
  }

  extractLastResponse() {
    for (const sel of this.SELECTORS.response) {
      const containers = document.querySelectorAll(sel);
      if (containers.length > 0) {
        const last = containers[containers.length - 1];
        const cloned = last.cloneNode(true);
        cloned.querySelectorAll('button, .action-buttons, .feedback-container, .ds-cursor, .ds-icon').forEach(el => el.remove());
        let text = (cloned.innerText || cloned.textContent || '').trim();
        text = text.replace(/[|█_●]$/, '').trim();
        return text;
      }
    }
    return '';
  }
}

window.DeepSeekProvider = DeepSeekProvider;
