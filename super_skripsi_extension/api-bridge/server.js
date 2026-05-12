const express = require('express');
const http = require('http');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const path = require('path');

const app = express();
const server = http.createServer(app);

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ limit: '50mb', extended: true }));

const PORT = process.env.PORT || 3000;
const IS_PROD = process.env.NODE_ENV === 'production';

// Serve Add-in static files
const addinPath = IS_PROD 
  ? path.join(__dirname, '..', '..', 'addin') 
  : path.join(__dirname, '..', '..', 'super_skripsi_addin', 'dist');

app.use('/addin', express.static(addinPath));
console.log(`[BRIDGE] Serving Add-in from: ${addinPath}`);

// --- State ---
const pendingQueues = {};   
const pendingRequests = {}; 
const lastSeen = {};        
const lastDelivery = {};    

// --- Real Traffic Tracking ---
let trafficStats = {
  totalHits: 0,
  countries: {} // { 'Indonesia': { hits: 1, lat: ..., lng: ..., color: ... } }
};

async function trackRequestTraffic(req) {
  try {
    let ip = req.headers['x-forwarded-for'] || req.socket.remoteAddress;
    
    // Handle localhost (detect real public IP for local testing)
    if (ip === '::1' || ip === '127.0.0.1' || ip.includes('::ffff:127.0.0.1')) {
      const ipResp = await fetch('https://api.ipify.org?format=json');
      const ipData = await ipResp.json();
      ip = ipData.ip;
    }

    const geoResp = await fetch(`http://ip-api.com/json/${ip}`);
    const geoData = await geoResp.json();

    if (geoData.status === 'success') {
      const countryName = geoData.country;
      if (!trafficStats.countries[countryName]) {
        trafficStats.countries[countryName] = {
          hits: 0,
          lat: geoData.lat,
          lng: geoData.lon,
          color: '#' + Math.floor(Math.random()*16777215).toString(16).padStart(6, '0')
        };
      }
      trafficStats.countries[countryName].hits++;
      trafficStats.totalHits++;
      console.log(`[TRAFFIC] New hit from ${countryName} (${ip})`);
    }
  } catch (err) {
    console.error(`[TRAFFIC ERROR] ${err.message}`);
  }
}

function getFormattedTraffic() {
  const countries = Object.keys(trafficStats.countries).map(name => {
    const c = trafficStats.countries[name];
    const percentage = trafficStats.totalHits > 0 
      ? Math.round((c.hits / trafficStats.totalHits) * 100) + '%' 
      : '0%';
    return {
      name,
      percentage,
      hits: c.hits,
      color: c.color,
      lat: c.lat,
      lng: c.lng
    };
  }).sort((a, b) => b.hits - a.hits);

  return {
    countries,
    totalHits: trafficStats.totalHits
  };
}

// --- Other State ---
let profile = {
  name: 'Administrator',
  email: 'admin@geminiflow.ai',
  role: 'Primary Owner',
  tier: 'Enterprise',
  activeSince: '2024'
};

let notifications = [
  {
    id: uuidv4(),
    title: 'Traffic Tracking Active',
    message: 'Real-time Geo-IP tracking is now monitoring incoming requests.',
    time: 'Just now',
    icon: 'check_circle',
    color: 'green',
    isCritical: false
  }
];

let supportTickets = [];
const logHistory = [];
const stats = {
  totalRequests: 0,
  successfulRequests: 0,
  failedRequests: 0,
  startTime: Date.now(),
};

function addLog(level, message, provider = 'system') {
  const log = { timestamp: new Date().toISOString(), level, message, provider };
  logHistory.push(log);
  if (logHistory.length > 100) logHistory.shift();
  
  const logLine = `[${log.timestamp}] [${level}] [${provider}] ${message}\n`;
  console.log(logLine.trim());
  
  // Append to file
  try {
    fs.appendFileSync(path.join(__dirname, 'activity.log'), logLine);
  } catch (err) {
    // Ignore log errors
  }
}

function getQueue(provider) {
  if (!pendingQueues[provider]) pendingQueues[provider] = [];
  return pendingQueues[provider];
}

app.get('/stats', (req, res) => {
  const providers = Object.keys(lastSeen).map(p => ({
    provider: p,
    lastSeen: new Date(lastSeen[p]).toISOString(),
    online: Date.now() - lastSeen[p] < 5000
  }));
  res.send({ 
    uptime: Math.floor((Date.now() - stats.startTime) / 1000),
    totalRequests: stats.totalRequests,
    successRate: stats.totalRequests > 0 ? (stats.successfulRequests / stats.totalRequests * 100).toFixed(2) : 100,
    activeProviders: providers.filter(p => p.online).length,
    providers,
    notifications,
    profile,
    trafficData: getFormattedTraffic()
  });
});

app.post('/api/:provider', (req, res) => {
  const { provider } = req.params;
  const { prompt, webhook } = req.body;
  
  trackRequestTraffic(req); // Trigger traffic tracking

  const id = uuidv4();
  stats.totalRequests++;
  addLog('INFO', `New prompt for ${provider}: ${id}`, provider);
  getQueue(provider).push({ id, prompt });
  pendingRequests[id] = { res: webhook ? null : res, timeout: null, callbackUrl: webhook, provider, receivedAt: Date.now() };
  if (webhook) res.send({ id, status: 'queued' });
});

let stopSignal = {}; // provider -> boolean

app.get('/api/clear', (req, res) => {
  const { provider } = req.query;
  if (provider) {
    pendingQueues[provider] = [];
    stopSignal[provider] = true;
    addLog('WARN', `Queue cleared for ${provider}`, provider);
  } else {
    // 1. Clear queues and BROADCAST stop signal
    const allProviders = ['gemini', 'deepseek', 'chatgpt', 'claude'];
    allProviders.forEach(p => {
      pendingQueues[p] = [];
      stopSignal[p] = true;
    });

    // 2. Clear dynamic queues
    Object.keys(pendingQueues).forEach(p => {
      pendingQueues[p] = [];
      stopSignal[p] = true;
    });

    // 3. REJECT all pending HTTP requests (Python is waiting here!)
    Object.keys(pendingRequests).forEach(id => {
      const { res: pendingRes } = pendingRequests[id];
      if (pendingRes && !pendingRes.writableEnded) {
        pendingRes.status(499).send({ 
          error: 'Process aborted by user request (Bridge Clear)',
          id: id 
        });
      }
      delete pendingRequests[id];
    });

    addLog('WARN', `All queues cleared, signals broadcasted, and ${Object.keys(pendingRequests).length} requests rejected.`);
  }
  res.send({ ok: true, message: 'All states cleared and pending requests aborted' });
});

app.get('/ext/poll/:provider', (req, res) => {
  const { provider } = req.params;
  lastSeen[provider] = Date.now();

  const queue = getQueue(provider);
  if (queue.length > 0) {
    const item = queue.shift();
    addLog('INFO', `Delivering ${item.id}`, provider);
    return res.send({ item });
  }
  res.send({ item: null });
});

// Endpoint baru khusus sinyal agar tidak rebutan dengan poll tasks
app.get('/ext/signal/:provider', (req, res) => {
  const { provider } = req.params;
  lastSeen[provider] = Date.now(); // CATAT SEBAGAI ONLINE!
  
  if (stopSignal[provider]) {
    stopSignal[provider] = false; // Reset setelah terkirim
    return res.send({ signal: 'STOP_PROCESSING' });
  }
  res.send({ signal: null });
});

app.post('/ext/result', (req, res) => {
  const { id, result, error } = req.body || {};
  if (pendingRequests[id]) {
    const { res: n8nRes } = pendingRequests[id];
    delete pendingRequests[id];
    if (error) stats.failedRequests++; else stats.successfulRequests++;
    if (n8nRes && !n8nRes.writableEnded) n8nRes.send({ result, error });
  }
  res.send({ ok: true });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on http://127.0.0.1:${PORT}`);
});
