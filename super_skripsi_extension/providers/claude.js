/* =============================================
   AI Auto-Flow — Claude Provider
   ============================================= */

class ClaudeProvider extends BaseProvider {
  constructor() {
    super();
    this.SELECTORS = {
      input: ['div[contenteditable="true"]', '[role="textbox"]'],
      send: ['button[aria-label="Send Message"]', 'button[aria-label="Send message"]'],
      stop: ['button[aria-label="Stop Response"]', 'button[aria-label="Stop response"]'],
      response: ['.font-claude-message', '.message-content']
    };
  }

  isAIGenerating() {
    const stopBtn = this.utils.findElement(this.SELECTORS.stop);
    return !!(stopBtn && stopBtn.offsetParent !== null);
  }

  async typeAndSend(text) {
    const inputEl = this.utils.findElement(this.SELECTORS.input);
    if (!inputEl) throw new Error('Cannot find Claude input area');

    inputEl.focus();
    inputEl.innerHTML = '';
    
    try {
      document.execCommand('selectAll', false, null);
      document.execCommand('delete', false, null);
      document.execCommand('insertText', false, text);
    } catch (e) {
      const p = document.createElement('p');
      p.textContent = text;
      inputEl.appendChild(p);
    }
    
    inputEl.dispatchEvent(new Event('input', { bubbles: true }));
    inputEl.dispatchEvent(new Event('change', { bubbles: true }));
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
    throw new Error('Failed to send prompt to Claude');
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

window.ClaudeProvider = ClaudeProvider;
