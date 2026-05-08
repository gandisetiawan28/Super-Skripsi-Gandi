/* =============================================
   AI Auto-Flow — Gemini Provider
   ============================================= */

class GeminiProvider extends BaseProvider {
  constructor() {
    super();
    this.SELECTORS = {
      input: [
        "div[aria-label='Masukkan perintah untuk Gemini']",
        "div[aria-label*='Gemini'][contenteditable='true']",
        ".ql-editor[contenteditable='true']", 
        "div[role='textbox'][contenteditable='true']"
      ],
      send: [
        "button[aria-label='Kirim pesan']",
        "button[aria-label*='Send']", 
        "button[aria-label*='Kirim']",
        "button.send-button"
      ],
      stop: [
        "button[aria-label='Hentikan respons']",
        "button[aria-label*='Stop']", 
        "button[aria-label*='Berhenti']",
        "button[aria-label*='Interrupt']"
      ],
      response: ['.model-response-text', '.message-content', 'message-content']
    };
  }

  findSendButton() {
    const inputEl = this.utils.findElement(this.SELECTORS.input);
    if (!inputEl) return null;

    // 1. Look for icon specifically within the input area container
    const container = inputEl.closest('.input-area-container, .input-container, [class*="input"]');
    if (container) {
      const icon = container.querySelector('mat-icon[data-mat-icon-name="send"], .send-button-icon');
      if (icon) {
        const btn = icon.closest('button');
        // KUNCI: Pastikan ikonnya memang "send", bukan "stop"
        if (btn && !btn.disabled && !btn.hasAttribute('disabled')) return btn;
      }
    }

    // 2. Global icon check
    const icon = document.querySelector('mat-icon[data-mat-icon-name="send"]');
    if (icon && icon.offsetParent !== null) {
      const btn = icon.closest('button');
      if (btn && !btn.disabled) return btn;
    }

    return null;
  }

  findStopButton() {
    // 1. Look for the stop icon name explicitly
    const stopIcon = document.querySelector('mat-icon[data-mat-icon-name="stop"], mat-icon[data-mat-icon-name="interrupt"], .stop-icon');
    if (stopIcon && stopIcon.offsetParent !== null) {
      return stopIcon.closest('button');
    }

    // 2. Fallback to selectors
    const btn = document.querySelector('button.stop, button[aria-label*="Hentikan"], button[aria-label*="Stop"], button[aria-label*="Interrupt"]');
    if (btn && btn.offsetParent !== null) {
      return btn;
    }

    return null;
  }

  stopGeneration() {
    const btn = this.findStopButton();
    if (btn) {
      console.log('[AI Auto-Flow] Forcing stop Gemini generation...');
      this.utils.robustClick(btn);
      return true;
    }
    console.warn('[AI Auto-Flow] Stop button not found or not active.');
    return false;
  }

  findContinueButton() {
    const candidates = document.querySelectorAll('button, div[role="button"], span, [aria-label*="Continue"], [aria-label*="Lanjut"]');
    for (const el of candidates) {
      if (el.offsetParent === null) continue;
      
      const text = el.innerText.trim();
      if (!text || text.length > 50) continue;
      
      const lowerText = text.toLowerCase();
      // Gemini "Continue" triggers
      const isContinue = (lowerText.includes('continue generating') || 
                          lowerText.includes('lanjutkan pembuatan') || 
                          lowerText.includes('tetap menulis') ||
                          lowerText.includes('keep writing')) && 
                         !lowerText.includes('coba lagi') && 
                         !lowerText.includes('regenerate');

      if (isContinue) {
        return el;
      }
    }
    return null;
  }

  isAIGenerating() {
    // 1. Check for the Stop button (provided by user)
    const stopBtn = this.findStopButton();
    if (stopBtn && stopBtn.offsetParent !== null) {
      return true;
    }

    // 2. Wajib: Anggap sedang "generating" jika tombol Continue muncul
    // Ini krusial agar extension tidak menganggap selesai saat jawaban terpotong
    if (this.findContinueButton()) {
      return true;
    }

    // 3. Priority: If Send button is active and enabled, we are definitely NOT generating
    // This is the most reliable "idle" signal.
    const sendBtn = this.findSendButton();
    if (sendBtn && !sendBtn.disabled && !sendBtn.hasAttribute('disabled')) {
      return false; 
    }

    // 4. Check for Gemini's specific progress/loading indicators
    const loading = document.querySelector('mat-progress-bar, .loading-indicator, [role="progressbar"], .typing-indicator');
    if (loading && loading.offsetParent !== null) {
      return true;
    }

    // 5. Check for "generating" state in the response bubbles
    const generatingText = document.querySelector('.model-response-text-generating, .processing, [aria-busy="true"]');
    if (generatingText && generatingText.offsetParent !== null) {
      return true;
    }

    // 6. Fallback: if no send button found at all, we might still be loading
    if (!sendBtn) return true;

    return false;
  }

  handleAutoFlow() {
    const continueBtn = this.findContinueButton();
    if (continueBtn) {
      const now = Date.now();
      // Beri delay 2 detik agar transisi smooth
      if (!this._lastContinueClick || now - this._lastContinueClick > 2000) {
        console.log('[AI Auto-Flow] Gemini terpotong. Mengklik "Lanjutkan pembuatan"...');
        this._lastContinueClick = now;
        this.utils.robustClick(continueBtn);
      }
    }
  }

  async typeAndSend(text) {
    const inputEl = this.utils.findElement(this.SELECTORS.input);
    if (!inputEl) throw new Error('Cannot find Gemini input area');

    // Use a more robust way to set content for large texts
    try {
      // 1. Focus and clear
      inputEl.focus();
      document.execCommand('selectAll', false, null);
      document.execCommand('delete', false, null);
      
      // 2. Try to use clipboard-style pasting for large text (much faster and stable)
      const dataTransfer = new DataTransfer();
      dataTransfer.setData('text/plain', text);
      const pasteEvent = new ClipboardEvent('paste', {
        clipboardData: dataTransfer,
        bubbles: true,
        cancelable: true
      });
      inputEl.dispatchEvent(pasteEvent);
      
      // 3. Fallback to insertText if paste didn't fill it
      if (inputEl.innerText.length < 10) {
        document.execCommand('insertText', false, text);
      }
    } catch (e) {
      console.warn('[Gemini] execCommand failed, falling back to innerText', e);
      inputEl.innerText = text;
    }
    
    // Dispatch events to trigger Gemini's internal state update
    const events = ['input', 'change', 'blur'];
    events.forEach(ev => inputEl.dispatchEvent(new Event(ev, { bubbles: true })));
    
    // Extra nudge for Angular/Gemini editor to recognize the change
    inputEl.dispatchEvent(new KeyboardEvent('keydown', { key: ' ', bubbles: true }));
    inputEl.dispatchEvent(new KeyboardEvent('keyup', { key: ' ', bubbles: true }));

    // Wait a bit longer for the UI to update with the large text
    await this.utils.sleep(1500);

    // 1. Try sending with Enter key
    const enterOpts = { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true };
    inputEl.dispatchEvent(new KeyboardEvent('keydown', enterOpts));
    inputEl.dispatchEvent(new KeyboardEvent('keyup', enterOpts));
    
    // Wait to see if it starts generating
    await this.utils.sleep(2000);
    if (this.isAIGenerating()) return;

    // 2. If Enter didn't work, try clicking the Send button
    let sendBtn = null;
    for (let i = 0; i < 10; i++) {
      sendBtn = this.findSendButton();
      // Ensure button is found and not disabled
      if (sendBtn && !sendBtn.disabled && !sendBtn.hasAttribute('disabled')) break;
      await this.utils.sleep(300);
    }

    if (sendBtn) {
      console.log('[AI Auto-Flow] Clicking Gemini send button...');
      this.utils.robustClick(sendBtn);
      
      // Wait longer for response to start
      for (let i = 0; i < 10; i++) {
        await this.utils.sleep(500);
        if (this.isAIGenerating()) return;
      }
    }
    
    throw new Error('Failed to send prompt to Gemini. Check if input was filled correctly.');
  }

  extractLastResponse() {
    for (const sel of this.SELECTORS.response) {
      const containers = document.querySelectorAll(sel);
      if (containers.length > 0) {
        const last = containers[containers.length - 1];
        const cloned = last.cloneNode(true);
        cloned.querySelectorAll('button, .action-buttons').forEach(el => el.remove());
        return (cloned.innerText || cloned.textContent || '').trim();
      }
    }
    return '';
  }
}

window.GeminiProvider = GeminiProvider;
