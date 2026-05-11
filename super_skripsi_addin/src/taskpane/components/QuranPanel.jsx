import React, { useState, useEffect, useMemo, useRef } from 'react';
import '../styles/quran.css';
import { insertQuranVerse, insertFullSurah, insertTafsir } from '../services/quranInjector';

const toArabicNumber = (n) => {
  if (!n) return '';
  return n.toString().split('').map(d => "٠١٢٣٤٥٦٧٨٩"[d]).join('');
};

export default function QuranPanel() {
  const [searchQuery, setSearchQuery] = useState('');
  const [surahs, setSurahs] = useState([]);
  const [selectedSurah, setSelectedSurah] = useState(null);
  const [verses, setVerses] = useState([]);
  const [tafsirData, setTafsirData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [isInserting, setIsInserting] = useState(false);
  const [selectedVerses, setSelectedVerses] = useState([]);
  const [expandedTafsir, setExpandedTafsir] = useState({});
  const [isPlaying, setIsPlaying] = useState(null); // stores verse number or surah number
  const [isFullPlaying, setIsFullPlaying] = useState(null); // stores surah number
  
  const audioRef = useRef(new Audio());

  // Fetch Surah List
  useEffect(() => {
    const fetchSurahs = async () => {
      setLoading(true);
      try {
        const response = await fetch('https://equran.id/api/v2/surat');
        const json = await response.json();
        if (json.code === 200) {
          setSurahs(json.data);
        }
      } catch (err) {
        console.error('Failed to fetch surahs:', err);
      } finally {
        setLoading(false);
      }
    };
    fetchSurahs();
  }, []);

  // Fetch Verses when Surah is selected
  const handleSelectSurah = async (surah) => {
    // Stop any playing audio when changing view
    audioRef.current.pause();
    setIsPlaying(null);
    setIsFullPlaying(null);

    setSelectedSurah(surah);
    setLoading(true);
    setVerses([]);
    setSelectedVerses([]);
    setExpandedTafsir({});
    try {
      const resSurat = await fetch(`https://equran.id/api/v2/surat/${surah.nomor}`);
      const dataSurat = await resSurat.json();
      
      const resTafsir = await fetch(`https://equran.id/api/v2/tafsir/${surah.nomor}`);
      const dataTafsir = await resTafsir.json();

      if (dataSurat.code === 200) {
        setVerses(dataSurat.data.ayat);
      }
      if (dataTafsir.code === 200) {
        setTafsirData(dataTafsir.data.tafsir);
      }
    } catch (err) {
      console.error('Failed to fetch verses:', err);
    } finally {
      setLoading(false);
    }
  };

  const filteredSurahs = useMemo(() => {
    return surahs.filter(s => 
      s.namaLatin.toLowerCase().includes(searchQuery.toLowerCase()) || 
      s.arti.toLowerCase().includes(searchQuery.toLowerCase())
    );
  }, [searchQuery, surahs]);

  const toggleTafsir = (nomor, e) => {
    e.stopPropagation();
    setExpandedTafsir(prev => ({ ...prev, [nomor]: !prev[nomor] }));
  };

  const toggleVerseSelection = (nomor) => {
    setSelectedVerses(prev => 
      prev.includes(nomor) ? prev.filter(vId => vId !== nomor) : [...prev, nomor]
    );
  };

  const playAudio = (verse, e) => {
    e.stopPropagation();
    const audioUrl = verse.audio['05']; 
    
    if (isPlaying === verse.nomorAyat) {
      audioRef.current.pause();
      setIsPlaying(null);
    } else {
      audioRef.current.src = audioUrl;
      audioRef.current.play();
      setIsPlaying(verse.nomorAyat);
      setIsFullPlaying(null);
      audioRef.current.onended = () => setIsPlaying(null);
    }
  };

  const playFullSurahAudio = (surah, e) => {
    e.stopPropagation();
    const audioUrl = surah.audioFull['05'];

    if (isFullPlaying === surah.nomor) {
      audioRef.current.pause();
      setIsFullPlaying(null);
    } else {
      audioRef.current.src = audioUrl;
      audioRef.current.play();
      setIsFullPlaying(surah.nomor);
      setIsPlaying(null);
      audioRef.current.onended = () => setIsFullPlaying(null);
    }
  };

  const playSelected = () => {
    if (selectedVerses.length === 0) return;
    const selectedData = verses.filter(v => selectedVerses.includes(v.nomorAyat)).sort((a,b) => a.nomorAyat - b.nomorAyat);
    let index = 0;
    
    const playNext = () => {
      if (index < selectedData.length) {
        const verse = selectedData[index];
        setIsPlaying(verse.nomorAyat);
        audioRef.current.src = verse.audio['05'];
        audioRef.current.play();
        audioRef.current.onended = () => {
          index++;
          playNext();
        };
      } else {
        setIsPlaying(null);
      }
    };
    playNext();
  };

  const handleInsertSingle = async (verse, e) => {
    e.stopPropagation();
    if (isInserting) return;
    setIsInserting(true);
    try {
      await insertQuranVerse({
        arabic: verse.teksArab,
        arabicNumber: toArabicNumber(verse.nomorAyat),
        translation: verse.teksIndonesia,
        surah: selectedSurah.namaLatin,
        ayat: verse.nomorAyat
      });
    } catch (error) {
      console.error(error);
    } finally {
      setIsInserting(false);
    }
  };

  const handleInsertTafsir = async (verse, e) => {
    e.stopPropagation();
    if (isInserting) return;
    setIsInserting(true);
    try {
      const tafsirObj = tafsirData.find(t => t.ayat === verse.nomorAyat);
      await insertTafsir({
        surah: selectedSurah.namaLatin,
        ayat: verse.nomorAyat,
        tafsir: tafsirObj?.teks || 'Tafsir tidak tersedia.',
        source: 'Kemenag RI'
      });
    } catch (error) {
      console.error(error);
    } finally {
      setIsInserting(false);
    }
  };

  const handleInsertSelected = async () => {
    if (selectedVerses.length === 0 || isInserting) return;
    setIsInserting(true);
    try {
      const versesToInsert = verses
        .filter(v => selectedVerses.includes(v.nomorAyat))
        .sort((a,b) => a.nomorAyat - b.nomorAyat)
        .map(v => ({
          id: v.nomorAyat,
          arabic: v.teksArab,
          translation: v.teksIndonesia
        }));
      await insertFullSurah({ surahName: selectedSurah.namaLatin, verses: versesToInsert });
      setSelectedVerses([]);
    } catch (err) {
      console.error(err);
    } finally {
      setIsInserting(false);
    }
  };

  return (
    <div className="quran-panel animate-in">
      {!selectedSurah ? (
        <>
          <div className="quran-header-info">
            <h2 className="panel-title">Al-Quran Digital</h2>
            <p className="panel-subtitle">Data resmi Kemenag RI & Murottal Misyari Rasyid.</p>
          </div>

          <div className="quran-search-container">
            <div className="search-box">
              <span className="search-icon">🔍</span>
              <input
                type="text"
                className="glass-input"
                placeholder="Cari Surah..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
              />
            </div>
          </div>

          {loading ? (
            <div className="loading-state">Memuat daftar surah...</div>
          ) : (
            <div className="surah-list">
              {filteredSurahs.map((surah) => {
                const isPlayingFull = isFullPlaying === surah.nomor;
                return (
                  <div key={surah.nomor} className="surah-item" onClick={() => handleSelectSurah(surah)}>
                    <div className="surah-number-hex">{surah.nomor}</div>
                    <div className="surah-info">
                      <div className="surah-name">{surah.namaLatin}</div>
                      <div className="surah-meta">{surah.arti} • {surah.jumlahAyat} Ayat</div>
                    </div>
                    <div className="surah-arabic-container">
                      <span className="surah-arabic-name">{surah.nama}</span>
                      <button 
                        className={`play-full-btn ${isPlayingFull ? 'playing' : ''}`}
                        onClick={(e) => playFullSurahAudio(surah, e)}
                        title="Putar Full Surah"
                      >
                        {isPlayingFull ? '⏸' : '▶'}
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </>
      ) : (
        <div className="verse-view">
          <header className="verse-header-premium">
            <button className="back-circle-btn" onClick={() => { setSelectedSurah(null); setVerses([]); audioRef.current.pause(); setIsPlaying(null); setIsFullPlaying(null); }}>←</button>
            <div className="selected-surah-details">
              <h3>{selectedSurah.namaLatin}</h3>
              <p>{selectedSurah.arti} • {selectedSurah.jumlahAyat} Ayat</p>
            </div>
            
            <div style={{ marginLeft: 'auto', display: 'flex', gap: '8px' }}>
              {selectedVerses.length > 0 && (
                <>
                  <button className="btn-use-small" style={{ background: '#3B82F6' }} onClick={playSelected}>
                    {isPlaying ? '⏸...' : `🔊 (${selectedVerses.length})`}
                  </button>
                  <button className="btn-use-small" style={{ background: '#10B981' }} onClick={handleInsertSelected} disabled={isInserting}>
                    {isInserting ? '...' : `Gunakan (${selectedVerses.length})`}
                  </button>
                </>
              )}
            </div>
          </header>

          {loading ? (
            <div className="loading-state">Memuat ayat dan audio...</div>
          ) : (
            <div className="verse-list">
              {verses.map((verse) => {
                const isSelected = selectedVerses.includes(verse.nomorAyat);
                const isTafsirOpen = expandedTafsir[verse.nomorAyat];
                const isVersePlaying = isPlaying === verse.nomorAyat;
                const tafsirObj = tafsirData?.find(t => t.ayat === verse.nomorAyat);

                return (
                  <div 
                    key={verse.nomorAyat} 
                    className={`verse-item-premium ${isSelected ? 'selected' : ''}`}
                    onClick={() => toggleVerseSelection(verse.nomorAyat)}
                  >
                    <div className="selection-indicator">✓</div>

                    <div className="verse-top">
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <span className="verse-pill">Ayat {verse.nomorAyat}</span>
                        <button 
                          className={`audio-mini-btn ${isVersePlaying ? 'playing' : ''}`}
                          onClick={(e) => playAudio(verse, e)}
                        >
                          {isVersePlaying ? '⏸' : '▶'}
                        </button>
                      </div>
                      <button className="btn-use-small" onClick={(e) => handleInsertSingle(verse, e)} disabled={isInserting}>
                        {isInserting ? '...' : 'Gunakan'}
                      </button>
                    </div>
                    
                    <div className="verse-content-container">
                      <div className="verse-number-col">
                        <span className="verse-index-badge">{verse.nomorAyat}</span>
                      </div>
                      <div className="verse-text-col">
                        <p className="arabic-text-large" style={{ color: isVersePlaying ? '#E53935' : '#1E293B' }}>
                          {verse.teksArab}
                        </p>
                        <p className="translation-text-premium">{verse.teksIndonesia}</p>
                      </div>
                    </div>

                    {(tafsirObj) && (
                      <div className="tafsir-container">
                        <div className="tafsir-actions">
                          <button className="btn-tafsir-toggle" onClick={(e) => toggleTafsir(verse.nomorAyat, e)}>
                            {isTafsirOpen ? '🔼 Tutup Tafsir' : '🔽 Lihat Tafsir'}
                          </button>
                          {isTafsirOpen && (
                            <button 
                              className="btn-use-small btn-use-secondary" 
                              style={{ fontSize: '10px', padding: '6px 12px' }}
                              onClick={(e) => handleInsertTafsir(verse, e)}
                              disabled={isInserting}
                            >
                              {isInserting ? '...' : 'Gunakan Tafsir'}
                            </button>
                          )}
                        </div>
                        {isTafsirOpen && (
                          <div className="tafsir-content" onClick={(e) => e.stopPropagation()}>
                            <span className="tafsir-source-label">Sumber: Kemenag RI</span>
                            {tafsirObj.teks}
                          </div>
                        )}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>
      )}
    </div>
  );
}
