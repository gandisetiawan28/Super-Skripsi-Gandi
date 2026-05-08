/* =============================================
   AI Auto-Flow — Base Provider & Utilities
   ============================================= */

window.AI_UTILS = {
  sleep: (ms) => new Promise(resolve => setTimeout(resolve, ms)),

  findElement: (selectorList) => {
    for (const sel of selectorList) {
      try {
        const elements = document.querySelectorAll(sel);
        for (const el of elements) {
          // Priority to visible elements
          if (el.offsetParent !== null) return el;
        }
        if (elements.length > 0) return elements[0];
      } catch (e) {}
    }
    return null;
  },

  setReactValue: (element, value) => {
    const lastValue = element.value;
    element.value = value;
    const event = new Event('input', { bubbles: true });
    // React 15
    event.simulated = true;
    // React 16
    const tracker = element._valueTracker;
    if (tracker) {
      tracker.setValue(lastValue);
    }
    element.dispatchEvent(event);
  },

  robustClick: (el) => {
    if (!el) return;
    const opts = { bubbles: true, cancelable: true, view: window };
    
    // Find closest element with a click method if current one doesn't have it
    let target = el;
    if (typeof target.click !== 'function') {
      target = el.closest('button, [role="button"], a, div') || el;
    }

    target.dispatchEvent(new MouseEvent('mousedown', opts));
    target.dispatchEvent(new MouseEvent('mouseup', opts));
    
    if (typeof target.click === 'function') {
      target.click();
    } else {
      // Fallback for elements without click() method
      target.dispatchEvent(new MouseEvent('click', opts));
    }
  }
};

class BaseProvider {
  constructor() {
    this.utils = window.AI_UTILS;
    this.stabilityThreshold = 10; // Default: 10 * 200ms = 2s
  }

  // To be implemented by children
  async typeAndSend(text) { throw new Error('Not implemented'); }
  isAIGenerating() { return false; }
  stopGeneration() { return false; }
  handleAutoFlow() { /* Optional UI automation (e.g. clicking Continue) */ }
  extractLastResponse() { return ''; }
  
  // Common wait cycle
  async waitForResponse(shouldStopCheck) {
    console.log('[AI Auto-Flow] Waiting for response...');
    return new Promise((resolve, reject) => {
      let resolved = false;
      let loadingStarted = false;
      let observer = null;
      let stabilityInterval = null;
      let noStartTimeout = null;
      let globalTimeout = null;
      
      const initialText = this.extractLastResponse();
      let lastText = initialText;
      let stableCount = 0;

      const cleanup = () => {
        if (observer) { observer.disconnect(); observer = null; }
        if (stabilityInterval) { clearInterval(stabilityInterval); stabilityInterval = null; }
        if (noStartTimeout) { clearTimeout(noStartTimeout); noStartTimeout = null; }
        if (globalTimeout) { clearTimeout(globalTimeout); globalTimeout = null; }
      };

      const done = (reason = 'Normal') => {
        if (resolved) return;
        console.log(`[AI Auto-Flow] Response detected: ${reason}`);
        resolved = true;
        cleanup();
        resolve();
      };

      const fail = (msg) => {
        if (resolved) return;
        console.error(`[AI Auto-Flow] Response failed: ${msg}`);
        resolved = true;
        cleanup();
        reject(new Error(msg));
      };

      const startStabilityCheck = () => {
        if (stabilityInterval) return; 
        console.log('[AI Auto-Flow] AI stopped generating, starting stability check...');
        stabilityInterval = setInterval(() => {
          if (resolved) return;
          if (shouldStopCheck()) return fail('Stopped by user');

          // If AI starts generating again (e.g. clicked Continue or transition), stop stability check
          if (this.isAIGenerating()) {
            console.log('[AI Auto-Flow] AI resumed generating, stopping stability check.');
            clearInterval(stabilityInterval);
            stabilityInterval = null;
            stableCount = 0;
            return;
          }

          const currentText = this.extractLastResponse();
          if (currentText === lastText && currentText !== '') {
            stableCount++;
            if (stableCount % 5 === 0) console.log(`[AI Auto-Flow] Stability check: ${stableCount}/${this.stabilityThreshold}`);
            if (stableCount >= this.stabilityThreshold) done('Stability'); 
          } else {
            if (stableCount > 0) console.log('[AI Auto-Flow] Stability reset (text changed or empty)');
            stableCount = 0;
          }
          lastText = currentText;
        }, 200);
      };

      const checkState = () => {
        if (resolved) return;
        if (shouldStopCheck()) return fail('Stopped by user');

        // Optional: Perform UI automation like clicking "Continue"
        this.handleAutoFlow();

        const generating = this.isAIGenerating();
        const currentText = this.extractLastResponse();
        // If text has changed from initial, it means the AI has started responding
        const hasResponded = currentText !== initialText && currentText !== '';

        if (generating) {
          loadingStarted = true;
          if (noStartTimeout) { clearTimeout(noStartTimeout); noStartTimeout = null; }
        } else {
          // If we were already generating and now stopped, OR if we missed the generating state but text changed
          if (loadingStarted || hasResponded) {
            // Instant finish if threshold is 0 and we have content
            if (this.stabilityThreshold === 0 && currentText !== '') {
              done('Instant');
              return;
            }

            if (!loadingStarted) {
               console.log('[AI Auto-Flow] Fast response detected (missed generating state).');
               loadingStarted = true;
               if (noStartTimeout) { clearTimeout(noStartTimeout); noStartTimeout = null; }
            }
            startStabilityCheck();
          }
        }
      };

      observer = new MutationObserver(checkState);
      observer.observe(document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ['aria-disabled', 'disabled', 'class', 'd']
      });

      checkState();

      noStartTimeout = setTimeout(() => {
        if (!loadingStarted && !resolved) {
          console.warn('[AI Auto-Flow] AI generation never started (no indicator found), continuing...');
          done('Timeout (No Start)');
        }
      }, 30000); // 30s timeout for startup

      globalTimeout = setTimeout(() => {
        if (!resolved) {
          console.error('[AI Auto-Flow] Global timeout reached (600s)');
          done('Timeout (Global)');
        }
      }, 1200000); // 20 min global timeout
    });
  }
}

window.BaseProvider = BaseProvider;
