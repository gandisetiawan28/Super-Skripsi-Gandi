/* =============================================
   AI Auto-Flow — Content Script (Router)
   ============================================= */

(function () {
  'use strict';

  let isRunning = false;
  let shouldStop = false;
  let currentProvider = null;

  // Initialize the correct provider based on URL
  function initProvider() {
    const host = window.location.hostname;
    if (host.includes('deepseek')) {
      currentProvider = new window.DeepSeekProvider();
      console.log('[AI Auto-Flow] DeepSeek Provider Initialized');
    } else if (host.includes('gemini')) {
      currentProvider = new window.GeminiProvider();
      console.log('[AI Auto-Flow] Gemini Provider Initialized');
    } else if (host.includes('chatgpt')) {
      currentProvider = new window.ChatGPTProvider();
      console.log('[AI Auto-Flow] ChatGPT Provider Initialized');
    } else if (host.includes('claude')) {
      currentProvider = new window.ClaudeProvider();
      console.log('[AI Auto-Flow] Claude Provider Initialized');
    } else {
      // Fallback or generic provider could be added here
      console.warn('[AI Auto-Flow] No specific provider found for this domain');
    }
  }

  initProvider();

  // --- Main Controller ---

  async function processPrompt(prompt) {
    if (!currentProvider) {
      throw new Error('No compatible AI provider found for this page.');
    }
    
    // 1. Type and Send
    await currentProvider.typeAndSend(prompt);
    
    // 2. Wait for response
    console.log('[AI Auto-Flow] Prompt sent, waiting for completion...');
    await currentProvider.waitForResponse(() => shouldStop);
    
    // 3. Extract result
    const result = currentProvider.extractLastResponse();
    console.log(`[AI Auto-Flow] Extraction complete (${result.length} chars)`);
    return result;
  }

  async function runLoop(prompts, delay, startIndex) {
    isRunning = true;
    shouldStop = false;
    
    for (let i = startIndex; i < prompts.length; i++) {
      if (shouldStop) {
        chrome.runtime.sendMessage({ type: 'LOOP_STOPPED', current: i, total: prompts.length });
        isRunning = false;
        return;
      }

      const prompt = prompts[i];
      chrome.runtime.sendMessage({ 
        type: 'PROGRESS_UPDATE', 
        current: i + 1, 
        total: prompts.length, 
        promptText: prompt 
      });

      try {
        const responseText = await processPrompt(prompt);
        chrome.runtime.sendMessage({ 
          type: 'RESPONSE_RECEIVED', 
          promptText: prompt, 
          responseText: responseText,
          index: i 
        });

        if (i < prompts.length - 1 && !shouldStop) {
          // Wait for the specified delay before next prompt
          await new Promise(r => setTimeout(r, delay));
        }
      } catch (err) {
        chrome.runtime.sendMessage({ type: 'ERROR', message: err.message });
        isRunning = false;
        return;
      }
    }

    chrome.runtime.sendMessage({ type: 'LOOP_COMPLETE', total: prompts.length });
    isRunning = false;
  }

  // --- Message Listener ---

  chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    switch (message.type) {
      case 'START_FLOW':
      case 'SINGLE_PROMPT':
        if (isRunning) {
          sendResponse({ success: false, error: 'Already running' });
          return;
        }
        isRunning = true;
        shouldStop = false; // RESET: Pastikan tidak nyangkut dari sesi sebelumnya
        processPrompt(message.prompt)
          .then(result => {
            const payload = message.type === 'SINGLE_PROMPT' ? { result } : { success: true, result };
            
            // Send back via callback (legacy/instant)
            sendResponse(payload);
            
            // Also send back via separate message (robust/MV3)
            chrome.runtime.sendMessage({
              type: 'SINGLE_PROMPT_RESULT',
              id: message.id, // We should add an ID to the message
              ...payload
            });
          })
          .catch(err => {
            const payload = { success: false, error: err.message };
            sendResponse(payload);
            chrome.runtime.sendMessage({
              type: 'SINGLE_PROMPT_RESULT',
              id: message.id,
              ...payload
            });
          })
          .finally(() => {
            isRunning = false;
          });
        return true;

      case 'START_LOOP':
        if (isRunning) {
          sendResponse({ success: false, error: 'Already running' });
          return;
        }
        runLoop(message.prompts, message.delay, message.startIndex);
        sendResponse({ success: true });
        break;

      case 'STOP_LOOP':
      case 'STOP_FLOW':
        shouldStop = true;
        // Physically click the stop button on the AI interface
        if (currentProvider && currentProvider.isAIGenerating()) {
          currentProvider.stopGeneration();
        }
        sendResponse({ success: true });
        break;

      case 'GET_STATUS':
        sendResponse({
          isRunning: isRunning,
          isAIGenerating: currentProvider ? currentProvider.isAIGenerating() : false
        });
        break;
    }
  });
  // --- Keep Alive System ---
  // Regularly pings background to keep Service Worker alive
  setInterval(() => {
    chrome.runtime.sendMessage({ type: 'KEEP_ALIVE_PING' }).catch(() => {
      // Background script might be temporarily asleep, 
      // but the act of trying to send a message will wake it up.
    });
  }, 20000); // Every 20 seconds

})();
