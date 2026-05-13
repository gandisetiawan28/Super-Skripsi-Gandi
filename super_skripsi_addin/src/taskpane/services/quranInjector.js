/**
 * Quran Injector Service
 * Handles specialized document injection for Quranic verses
 */

/**
 * Helper to format verse ranges into a readable string
 */
function formatVerseRange(verses) {
  if (!verses || verses.length === 0) return "";
  const ids = verses.map(v => v.id).sort((a, b) => a - b);
  
  const parts = [];
  let start = ids[0];
  let current = ids[0];

  for (let i = 1; i <= ids.length; i++) {
    if (i < ids.length && ids[i] === current + 1) {
      current = ids[i];
    } else {
      if (start === current) {
        parts.push(`${start}`);
      } else {
        parts.push(`${start}-${current}`);
      }
      if (i < ids.length) {
        start = ids[i];
        current = ids[i];
      }
    }
  }
  return parts.join(', ');
}

/**
 * Insert Al-Quran verse with proper formatting (Arabic + Translation)
 */
export async function insertQuranVerse({ arabic, arabicNumber, translation, surah, ayat }) {
  return Word.run(async (context) => {
    const selection = context.document.getSelection();
    
    const html = `
      <div style="margin-bottom: 10pt;">
        <p style="text-align: right; font-family: 'Traditional Arabic', 'Amiri', 'Arial', serif; font-size: 12pt; line-height: 1.8; direction: rtl; unicode-bidi: embed;">
          ${arabic} <span style="color: #000000; font-size: 12pt;">&#x06DD;${arabicNumber}</span>
        </p>
        <p style="text-align: justify; font-family: 'Times New Roman', serif; font-size: 11pt; font-style: italic; color: #555555; line-height: 1.5;">
          Terjemahan: "${translation}" (Q.S. ${surah}:${ayat}).
        </p>
      </div>
    `;

    const range = selection.insertHtml(html, Word.InsertLocation.replace);
    
    // Add a new empty paragraph after the content for easy typing
    range.insertParagraph("", Word.InsertLocation.after);
    
    range.select(Word.SelectionMode.end);
    await context.sync();
    
    const curSelection = context.document.getSelection();
    curSelection.font.italic = false;
    curSelection.font.size = 12;
    await context.sync();
  });
}

/**
 * Insert all verses of a Surah as unified blocks (Mushaf Style)
 */
export async function insertFullSurah({ surahName, verses }) {
  return Word.run(async (context) => {
    const selection = context.document.getSelection();
    
    const toAr = (n) => n.toString().split('').map(d => "٠١٢٣٤٥٦٧٨٩"[d]).join('');

    // Merge Arabic text: Ensure Verse -> Number order in RTL
    const combinedArabic = verses.map(v => 
      `${v.arabic} <span style="color: #000000; font-size: 12pt;">&#x06DD;${toAr(v.id)}</span>`
    ).join(' ');

    // Merge translations: (1) Text (2) Text
    const combinedTranslations = verses.map(v => 
      `(${v.id}) ${v.translation}`
    ).join(' ');

    // Calculate citation range (e.g., 1-2, 4)
    const rangeText = formatVerseRange(verses);

    const html = `
      <div style="margin-bottom: 15pt;">
        <p style="text-align: right; font-family: 'Traditional Arabic', 'Amiri', 'Arial', serif; font-size: 12pt; line-height: 2.2; direction: rtl; unicode-bidi: embed; margin-bottom: 8pt;">
          ${combinedArabic}
        </p>
        <p style="text-align: justify; font-family: 'Times New Roman', serif; font-size: 11pt; font-style: italic; color: #444444; line-height: 1.6;">
          Terjemahan: "${combinedTranslations}" (Q.S. ${surahName}:${rangeText}).
        </p>
      </div>
    `;

    const range = selection.insertHtml(html, Word.InsertLocation.replace);
    
    // Add a new empty paragraph after
    range.insertParagraph("", Word.InsertLocation.after);

    range.select(Word.SelectionMode.end);
    await context.sync();
    
    const curSelection = context.document.getSelection();
    curSelection.font.italic = false;
    curSelection.font.size = 12;
    await context.sync();
  });
}

/**
 * Insert Tafsir text with its source citation
 */
export async function insertTafsir({ surah, ayat, tafsir, source }) {
  return Word.run(async (context) => {
    const selection = context.document.getSelection();
    
    const html = `
      <div style="margin-top: 10pt; margin-bottom: 10pt; padding: 10pt; border-left: 3pt solid #E53935; background-color: #F9F9F9;">
        <p style="font-family: 'Times New Roman', serif; font-size: 11pt; font-weight: bold; color: #E53935; margin-bottom: 5pt;">
          Tafsir Q.S. ${surah}:${ayat} (${source})
        </p>
        <p style="font-family: 'Times New Roman', serif; font-size: 11pt; line-height: 1.6; text-align: justify; color: #333333;">
          ${tafsir}
        </p>
      </div>
    `;

    const range = selection.insertHtml(html, Word.InsertLocation.replace);
    
    // Add a new empty paragraph after
    range.insertParagraph("", Word.InsertLocation.after);

    range.select(Word.SelectionMode.end);
    await context.sync();
  });
}
