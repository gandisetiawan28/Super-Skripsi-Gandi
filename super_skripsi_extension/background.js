/* =============================================
   AI Auto-Flow — Background Script (MV3)
   Uses HTTP Polling instead of WebSocket/Socket.io
   for full Chrome MV3 Service Worker compatibility.
   ============================================= */

let apiConfig = { enabled: false, url: 'http://127.0.0.1:3000', provider: 'gemini' };
let status = 'disabled';
let pollSessionId = 0;
let pollTimer = null;
let isProcessing = false;

// Load initial config
chrome.storage.local.get(['apiConfig'], (data) => {
  if (data.apiConfig) {
    apiConfig = data.apiConfig;
    if (apiConfig.enabled) startPolling();
  }
});

// Listen for config changes from popup
chrome.storage.onChanged.addListener((changes) => {
  if (changes.apiConfig) {
    apiConfig = changes.apiConfig.newValue;
    if (apiConfig.enabled) {
      startPolling();
    } else {
      stopPolling();
    }
  }
});

function updateStatus(newStatus) {
  status = newStatus;
  chrome.storage.local.set({ apiStatus: newStatus });
  chrome.runtime.sendMessage({ type: 'STATUS_UPDATE', status }).catch(() => {});
}

let taskPollTimer = null;
let signalPollTimer = null;

function startPolling() {
  stopPolling();
  if (!apiConfig.url || !apiConfig.enabled) return;

  pollSessionId++;
  const currentSession = pollSessionId;
  updateStatus('connected');
  
  chrome.alarms.create('keepAlive', { periodInMinutes: 1 });
  
  console.log(`[Background] Polling started (Session: ${currentSession})`);
  pollTasks(currentSession);
  pollSignals(currentSession);
}

function stopPolling() {
  pollSessionId++;
  if (taskPollTimer) { clearTimeout(taskPollTimer); taskPollTimer = null; }
  if (signalPollTimer) { clearTimeout(signalPollTimer); signalPollTimer = null; }
  chrome.alarms.clear('keepAlive');
  if (status !== 'disabled') updateStatus('disabled');
}

// Sensor Bangun: Pastikan ekstensi tidak "tidur" selamanya
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'keepAlive' && apiConfig.enabled) {
    console.log('[Background] ⏰ Bangun! Mengecek koneksi...');
    if (!taskPollTimer || !signalPollTimer) {
       startPolling();
    }
  }
});

// Jalur Khusus SINYAL (Emergency Polling)
async function pollSignals(sessionId) {
  if (sessionId !== pollSessionId || !apiConfig.enabled) return;

  const provider = apiConfig.provider || 'gemini';
  try {
    let baseUrl = (apiConfig.url || 'http://127.0.0.1:3000').trim();
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.slice(0, -1);
    const signalUrl = `${baseUrl}/ext/signal/${provider}`;

    const response = await fetch(signalUrl, { method: 'GET' });
    const data = await response.json();
    
    if (data.signal === 'STOP_PROCESSING') {
       console.log('[Background] 🛑 Emergency STOP signal received!');
       await stopOngoingProcessing();
       // Beri tahu popup agar UI berubah ke standby
       chrome.runtime.sendMessage({ type: 'STATUS_UPDATE', status: 'connected' }).catch(() => {});
    }
  } catch (err) {
    // Silent fail for signal polling
  }

  if (sessionId === pollSessionId && apiConfig.enabled) {
    signalPollTimer = setTimeout(() => pollSignals(sessionId), 1000);
  }
}

// Jalur Khusus TUGAS (Task Polling)
async function pollTasks(sessionId) {
  if (sessionId !== pollSessionId || !apiConfig.enabled || isProcessing) {
    if (sessionId === pollSessionId && apiConfig.enabled) {
      taskPollTimer = setTimeout(() => pollTasks(sessionId), 500);
    }
    return;
  }

  let baseUrl = (apiConfig.url || 'http://127.0.0.1:3000').trim();
  if (baseUrl.endsWith('/')) baseUrl = baseUrl.slice(0, -1);
  
  const provider = apiConfig.provider || 'gemini';
  const pollUrl = `${baseUrl}/ext/poll/${provider}`;

  try {
    const response = await fetch(pollUrl, { method: 'GET' });
    const data = await response.json();

    if (data.item) {
      const { id, prompt } = data.item;
      console.log(`[Background] Processing prompt: ${id}`);
      isProcessing = true;
      chrome.runtime.sendMessage({ type: 'API_START', id, prompt }).catch(() => {});
      
      try {
        const result = await processPromptOnTarget(prompt);
        await sendResult(baseUrl, id, { result: result || '' });
      } catch (err) {
        console.error('[Background] Error:', err.message);
        await sendResult(baseUrl, id, { error: err.message });
      } finally {
        isProcessing = false;
        chrome.runtime.sendMessage({ type: 'API_END', id }).catch(() => {});
      }
    }
    if (status !== 'connected') updateStatus('connected');
  } catch (err) {
    const provider = apiConfig.provider || 'gemini';
    console.error(`[Background] Bridge connection error (${provider}):`, err.message);
    
    // Only set error status if it's a real connection failure, not a script error
    if (err instanceof TypeError || err.message.includes('fetch')) {
       if (status !== 'error') updateStatus('error');
    }
    
    // Diagnostic: check if server is reachable on 127.0.0.1 as fallback if configured with localhost
    if (baseUrl.includes('localhost')) {
       console.log('[Background] Diagnostic: Suggesting switch from localhost to 127.0.0.1');
    }
  }

  if (sessionId === pollSessionId && apiConfig.enabled) {
    taskPollTimer = setTimeout(() => pollTasks(sessionId), 500);
  }
}

async function stopOngoingProcessing() {
  const provider = apiConfig.provider || 'gemini';
  const domains = {
    gemini: 'gemini.google.com',
    chatgpt: 'chatgpt.com',
    claude: 'claude.ai',
    deepseek: 'deepseek.com'
  };

  const targetDomain = domains[provider];
  const tabs = await chrome.tabs.query({});
  const tab = tabs.find(t => t.url && t.url.includes(targetDomain));

  if (tab) {
    chrome.tabs.sendMessage(tab.id, { type: 'STOP_FLOW' }).catch(() => {});
    console.log(`[Background] Stop signal sent to ${provider} tab.`);
  }
  isProcessing = false; // Reset local state
}

async function sendResult(baseUrl, id, payload) {
  try {
    await fetch(`${baseUrl}/ext/result`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ id, ...payload })
    });
    console.log(`[Background] Result sent for: ${id}`);
  } catch (err) {
    console.error('[Background] Failed to send result:', err.message);
  }
}

async function processPromptOnTarget(promptText) {
  const provider = apiConfig.provider || 'gemini';
  const domains = {
    gemini: 'gemini.google.com',
    chatgpt: 'chatgpt.com',
    claude: 'claude.ai',
    deepseek: 'deepseek.com'
  };

  const targetDomain = domains[provider];
  const tabs = await chrome.tabs.query({});
  const tab = tabs.find(t => t.url && t.url.includes(targetDomain));

  if (!tab) {
    throw new Error(`No ${provider} tab found. Please open ${targetDomain}`);
  }

  return new Promise((resolve, reject) => {
    const promptId = Math.random().toString(36).substring(2, 11);
    let resolved = false;

    // Listener for robust response
    const listener = (msg) => {
      if (msg.type === 'SINGLE_PROMPT_RESULT' && msg.id === promptId) {
        chrome.runtime.onMessage.removeListener(listener);
        if (resolved) return;
        resolved = true;
        if (msg.error) reject(new Error(msg.error));
        else resolve(msg.result);
      }
    };
    chrome.runtime.onMessage.addListener(listener);

    // Timeout as failsafe
    setTimeout(() => {
      chrome.runtime.onMessage.removeListener(listener);
      if (!resolved) {
        resolved = true;
        reject(new Error('Timeout waiting for AI response (600s)'));
      }
    }, 1200000); // 20 min failsafe

    chrome.tabs.sendMessage(tab.id, {
      type: 'SINGLE_PROMPT',
      prompt: promptText,
      id: promptId
    }, (response) => {
      if (chrome.runtime.lastError) {
        console.warn('[Background] Tab callback error (ignoring if robust listener works):', chrome.runtime.lastError.message);
      } else if (response) {
        if (resolved) return;
        resolved = true;
        chrome.runtime.onMessage.removeListener(listener);
        if (response.error) reject(new Error(response.error));
        else resolve(response.result);
      }
    });
  });
}

// Handle messages from popup & content script
chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === 'GET_BRIDGE_STATUS') {
    sendResponse({ status });
  } else if (msg.type === 'FORCE_RECONNECT') {
    console.log('[Background] 🔄 Force reconnect requested...');
    // Muat ulang config terbaru sebelum start
    chrome.storage.local.get(['apiConfig'], (data) => {
      if (data.apiConfig) {
        apiConfig = data.apiConfig;
        if (apiConfig.enabled) startPolling();
      }
    });
    sendResponse({ status: 'reconnecting' });
  } else if (msg.type === 'KEEP_ALIVE_PING') {
    // Content script sending ping to keep SW awake
    console.log('[Background] Received keep-alive ping from tab');
    if (apiConfig.enabled && status === 'disabled') {
       startPolling();
    }
    sendResponse({ ok: true });
  }
  return true;
});
