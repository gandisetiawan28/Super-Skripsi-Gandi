// updater_backend/api/index.js
// Backend untuk menangani update otomatis dari repository GitHub Private

export default async function handler(req, res) {
  // 1. Ambil Token & Config dari Environment Variables di Vercel
  const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
  const REPO_OWNER = process.env.REPO_OWNER || 'gandisetiawan28';
  const REPO_NAME = process.env.REPO_NAME || 'Super_Skripsi_Gandi';
  const APP_SECRET_KEY = process.env.APP_SECRET_KEY; // Key rahasia agar hanya aplikasi Anda yang bisa akses

  // 2. Keamanan: Cek apakah request memiliki key yang benar
  const clientKey = req.headers['x-app-key'];
  if (APP_SECRET_KEY && clientKey !== APP_SECRET_KEY) {
    return res.status(401).json({ error: 'Unauthorized: Invalid App Key' });
  }

  try {
    // 3. Ambil data release terbaru dari GitHub API
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

    // 4. Sederhanakan data untuk dikirim ke Flutter
    const updateInfo = {
      version: data.tag_name.replace('v', ''),
      notes: data.body,
      published_at: data.published_at,
      assets: data.assets.map(asset => ({
        name: asset.name,
        // Kita beri URL proxy agar user bisa download file dari repo private via Vercel
        download_url: asset.browser_download_url, 
        size: asset.size
      }))
    };

    return res.status(200).json(updateInfo);

  } catch (error) {
    return res.status(500).json({ error: 'Internal Server Error', message: error.message });
  }
}
