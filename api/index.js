// updater_backend/api/index.js
// Backend untuk menangani update otomatis dari repository GitHub Private

export default async function handler(req, res) {
  // 1. Ambil Token & Config dari Environment Variables di Vercel
  const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
  const REPO_OWNER = process.env.REPO_OWNER || 'gandisetiawan28';
  const REPO_NAME = process.env.REPO_NAME || 'Super_Skripsi_Gandi';
  const APP_SECRET_KEY = process.env.APP_SECRET_KEY; // Key rahasia agar hanya aplikasi Anda yang bisa akses

  // 2. Keamanan: Cek apakah request memiliki key yang benar
  const clientKey = req.headers['x-app-key'] || req.query.key;
  if (APP_SECRET_KEY && clientKey !== APP_SECRET_KEY) {
    return res.status(401).json({ error: 'Unauthorized: Invalid App Key' });
  }

  try {
    // 4. JIKA REQUEST ADALAH DOWNLOAD (PROXY)
    const { action, asset_id } = req.query;
    if (action === 'download' && asset_id) {
      const assetResponse = await fetch(
        `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/assets/${asset_id}`,
        {
          headers: {
            'Authorization': `Bearer ${GITHUB_TOKEN}`,
            'Accept': 'application/octet-stream',
          },
        }
      );

      if (!assetResponse.ok) {
        return res.status(assetResponse.status).json({ error: 'Failed to download asset from GitHub' });
      }

      // Kirim file sebagai stream agar hemat memori
      res.setHeader('Content-Type', 'application/octet-stream');
      res.setHeader('Content-Disposition', `attachment; filename=SuperSkripsi_Setup.exe`);
      
      const arrayBuffer = await assetResponse.arrayBuffer();
      return res.send(Buffer.from(arrayBuffer));
    }

    // 5. REQUEST BIASA: Cek Release Terbaru
    const response = await fetch(
      `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/releases/latest`,
      {
        headers: {
          'Authorization': `Bearer ${GITHUB_TOKEN}`,
          'Accept': 'application/vnd.github.v3+json',
        },
      }
    );

    if (!response.ok) {
      const errorData = await response.json();
      return res.status(response.status).json({ 
        error: 'Failed to fetch from GitHub', 
        details: errorData 
      });
    }

    const data = await response.json();

    // Sederhanakan data untuk dikirim ke Flutter
    // Kita buat URL download yang mengarah kembali ke Vercel ini (Proxy)
    const protocol = req.headers['x-forwarded-proto'] || 'http';
    const host = req.headers.host;
    const baseUrl = `${protocol}://${host}/api`;

    const updateInfo = {
      version: data.tag_name.replace('v', ''),
      notes: data.body,
      published_at: data.published_at,
      assets: data.assets.map(asset => ({
        name: asset.name,
        // URL Proxy: agar aplikasi mendownload lewat Vercel (yang punya Token)
        download_url: `${baseUrl}?action=download&asset_id=${asset.id}&key=${APP_SECRET_KEY}`, 
        size: asset.size
      }))
    };

    return res.status(200).json(updateInfo);

  } catch (error) {
    return res.status(500).json({ error: 'Internal Server Error', message: error.message });
  }
}
