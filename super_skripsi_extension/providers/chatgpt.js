/* =============================================
   AI Auto-Flow — ChatGPT Provider
   ============================================= */

class ChatGPTProvider extends BaseProvider {
  constructor() {
    super();
    this.SELECTORS = {
      input: ['#prompt-textarea', 'textarea'],
      send: ['button[data-testid="send-button"]', 'button[aria-label="Send prompt"]'],
      stop: ['button[data-testid="stop-button"]', 'button[aria-label="Stop generating"]'],
      response: ['.markdown', '.message-content']
    };
  }

  isAIGenerating() {
    const stopBtn = this.utils.findElement(this.SELECTORS.stop);
    return !!(stopBtn && stopBtn.offsetParent !== null);
  }

  async typeAndSend(text) {
    const inputEl = this.utils.findElement(this.SELECTORS.input);
    if (!inputEl) throw new Error('Cannot find ChatGPT input area');

    this.utils.setReactValue(inputEl, text);
    await this.utils.sleep(600);

    // Try Enter
    const enterOpts = { key: 'Enter', code: 'Enter', keyCode: 13, which: 13, bubbles: true };
    inputEl.dispatchEvent(new KeyboardEvent('keydown', enterOpts));
    inputEl.dispatchEvent(new KeyboardEvent('keyup', enterOpts));
    
    await this.utils.sleep(1000);
    if (this.isAIGenerating()) return;

    // Try Click
    const sendBtn = this.utils.findElement(this.SELECTORS.send);
    if (sendBtn) {
      this.utils.robustClick(sendBtn);
      return;
    }
    throw new Error('Failed to send prompt to ChatGPT');
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

window.ChatGPTProvider = ChatGPTProvider;
