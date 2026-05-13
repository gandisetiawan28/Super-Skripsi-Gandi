/**
 * Word Injector Service
 * Seamlessly injects text into Microsoft Word at cursor position using Word.run() API
 */

/**
 * Insert plain text at the current cursor position
 */
export async function insertTextAtCursor(text) {
  return Word.run(async (context) => {
    const selection = context.document.getSelection();
    selection.insertText(text, Word.InsertLocation.replace);
    await context.sync();
  });
}

/**
 * Insert text with HTML support (for italics) at the current cursor position
 */
export async function insertFormattedText(text) {
  return Word.run(async (context) => {
    const selection = context.document.getSelection();
    
    // Split text into paragraphs by double newlines
    const paragraphs = text.split(/\n\s*\n/).filter(p => p.trim().length > 0);
    
    // Wrap each paragraph in its own <p> tag with academic styling
    const html = paragraphs.map(p => {
      const content = escapeHtml(p.trim()).replace(/\n/g, '<br/>');
      return `<p style="text-align: justify; font-family: 'Times New Roman', serif; font-size: 12pt; line-height: 2;">
        ${content}
      </p>`;
    }).join('');

    const range = selection.insertHtml(html, Word.InsertLocation.replace);
    
    // Select the end of the newly inserted content
    range.select(Word.SelectionMode.end);
    
    // Reset formatting explicitly on the new selection/cursor
    await context.sync(); // Sync to ensure range is at the end
    
    const curSelection = context.document.getSelection();
    curSelection.font.subscript = false;
    curSelection.font.superscript = false;
    curSelection.font.italic = false;
    
    await context.sync();
  });
}

/**
 * Insert formatted HTML at the current cursor position
 */
export async function insertHtmlAtCursor(html) {
  return Word.run(async (context) => {
    const selection = context.document.getSelection();
    const range = selection.insertHtml(html, Word.InsertLocation.replace);
    
    range.select(Word.SelectionMode.end);
    await context.sync();

    const curSelection = context.document.getSelection();
    curSelection.font.subscript = false;
    curSelection.font.superscript = false;
    curSelection.font.italic = false;

    await context.sync();
  });
}

/**
 * Insert paraphrase + citation as formatted academic text
 * Format: "{paraphrase text} {citation}."
 */
export async function insertAcademicText({ paraphrase, citation }) {
  // Build the properly formatted text
  // Citation goes at the end of the sentence, before the period
   let formattedText = paraphrase.trim();
 
   // Jika sitasi disediakan terpisah, gabungkan di akhir sebelum titik
   if (citation && citation.trim()) {
     if (formattedText.endsWith('.')) {
       formattedText = formattedText.slice(0, -1);
     }
     formattedText = `${formattedText} (${citation.replace(/[()]/g, '')})`;
   }
 
   // Tambahkan titik jika belum ada
   const finalText = formattedText.endsWith('.') ? formattedText : `${formattedText}.`;

  return Word.run(async (context) => {
    const selection = context.document.getSelection();

    // Insert as HTML to maintain formatting
    // Split into paragraphs for double newlines, use <br/> for single newlines
    const paragraphs = finalText.split(/\n\s*\n/).filter(p => p.trim().length > 0);
    const html = paragraphs.map(p => {
      const content = escapeHtml(p.trim()).replace(/\n/g, '<br/>');
      return `<p style="text-align: justify; font-family: 'Times New Roman', serif; font-size: 12pt; line-height: 2;">
        ${content}
      </p>`;
    }).join('');

    const range = selection.insertHtml(html, Word.InsertLocation.replace);
    range.insertParagraph("", Word.InsertLocation.after);
    range.select(Word.SelectionMode.end);
    await context.sync();

    const curSelection = context.document.getSelection();
    curSelection.font.subscript = false;
    curSelection.font.superscript = false;
    curSelection.font.italic = false;

    await context.sync();
  });
}

/**
 * Insert verbatim quote with proper formatting
 */
export async function insertVerbatimQuote({ verbatim, citation }) {
  // Bersihkan teks dari tanda kutip di awal/akhir agar tidak dobel
  let text = verbatim.trim().replace(/^["']|["']$/g, '');
  if (text.endsWith('.')) text = text.slice(0, -1);

  // Format sitasi dalam kurung
  const cleanCitation = citation ? ` (${citation.replace(/[()]/g, '')})` : '';

  // Short quotes (under 40 words) use inline quotes
  const wordCount = text.split(/\s+/).length;

  return Word.run(async (context) => {
    const selection = context.document.getSelection();
    let html;

    if (wordCount < 40) {
      // Inline quote: "Teks" (Penulis, Tahun).
      html = `<p style="text-align: justify; font-family: 'Times New Roman', serif; font-size: 12pt; line-height: 2;">
        "${escapeHtml(text)}"${escapeHtml(cleanCitation)}.
      </p>`;
    } else {
      // Block quote: Teks (Penulis, Tahun).
      html = `<p style="text-align: justify; font-family: 'Times New Roman', serif; font-size: 12pt; line-height: 2; margin-left: 0.5in;">
        ${escapeHtml(text)}${escapeHtml(cleanCitation)}.
      </p>`;
    }

    const range = selection.insertHtml(html, Word.InsertLocation.replace);
    range.insertParagraph("", Word.InsertLocation.after);
    range.select(Word.SelectionMode.end);
    await context.sync();

    const curSelection = context.document.getSelection();
    curSelection.font.subscript = false;
    curSelection.font.superscript = false;
    curSelection.font.italic = false;

    await context.sync();
  });
}

/**
 * Read the currently selected (highlighted) text from the Word document
 * This version attempts to preserve sub/sup formatting by reading as HTML first
 */
export async function getSelectedText() {
  return Word.run(async (context) => {
    const selection = context.document.getSelection();
    
    // We fetch both HTML and text
    // HTML is used to detect sub/sup tags
    const html = selection.getHtml();
    selection.load('text');
    await context.sync();

    const rawHtml = html.value || '';
    const plainText = selection.text || '';

    // If HTML contains sub/sup signatures, use the tag-preserving cleaner
    if (rawHtml.includes('sub') || rawHtml.includes('sup') || rawHtml.includes('vertical-align')) {
      return cleanWordHtmlForAI(rawHtml) || plainText;
    }

    return plainText;
  });
}

/**
 * Basic cleaner to extract text but keep sub/sup tags from Word HTML
 * Handles both standard tags and Word's common CSS-based sub/sup
 */
function cleanWordHtmlForAI(html) {
  try {
    // 1. Remove all styles and extra meta
    let cleaned = html.replace(/<style([\s\S]*?)<\/style>/gi, '');
    cleaned = cleaned.replace(/<xml([\s\S]*?)<\/xml>/gi, '');
    
    // 2. Identify <sub> and <sup> blocks in Word's messy CSS
    // Word often uses <span style='vertical-align:sub'> or <span style='mso-element:subscript'>
    // We normalize these to standard tags
    cleaned = cleaned.replace(/<span[^>]*style=[^>]*vertical-align:\s*(sub|super)[^>]*>([\s\S]*?)<\/span>/gi, (match, type, content) => {
      const tag = type.toLowerCase().startsWith('sub') ? 'sub' : 'sup';
      return `<${tag}>${content}</${tag}>`;
    });

    // 3. Normalize standard <sub> and <sup> if they already exist
    cleaned = cleaned.replace(/<sub([\s\S]*?)>([\s\S]*?)<\/sub>/gi, '<sub>$2</sub>');
    cleaned = cleaned.replace(/<sup([\s\S]*?)>([\s\S]*?)<\/sup>/gi, '<sup>$2</sup>');
    
    // 4. Remove all other tags but keep content
    cleaned = cleaned.replace(/<(?!sub|sup|\/sub|\/sup)([\s\S]*?)>/gi, '');
    
    // 5. Decode common entities & whitespace fix
    cleaned = cleaned.replace(/&nbsp;/g, ' ')
                   .replace(/&amp;/g, '&')
                   .replace(/\s+/g, ' ');
    
    return cleaned.trim();
  } catch (e) {
    return null;
  }
}

function escapeHtml(text) {
  if (!text) return text;
  
  // Convert Markdown syntax to HTML tags
  let parsedText = text.replace(/\*\*([^\*]+)\*\*/g, '<b>$1</b>'); // Bold
  parsedText = parsedText.replace(/\*([^\*]+)\*/g, '<i>$1</i>');     // Italic
  parsedText = parsedText.replace(/_([^_]+)_/g, '<i>$1</i>');        // Italic (underscore)

  // First, auto-close any orphaned tags to prevent formatting leakage
  const sanitized = sanitizeHtmlTags(parsedText);
  
  const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
  let escaped = sanitized.replace(/[&<>"']/g, (m) => map[m]);
  
  // Restore allowed formatting tags specifically for Word HTML injection
  return escaped
    .replace(/&lt;i&gt;/g, '<i>').replace(/&lt;\/i&gt;/g, '</i>')
    .replace(/&lt;b&gt;/g, '<b>').replace(/&lt;\/b&gt;/g, '</b>')
    .replace(/&lt;sub&gt;/g, '<sub>').replace(/&lt;\/sub&gt;/g, '</sub>')
    .replace(/&lt;sup&gt;/g, '<sup>').replace(/&lt;\/sup&gt;/g, '</sup>');
}

/**
 * Ensures sub/sup tags are properly closed right after the symbol.
 * Exported so ParafrasePanel can sanitize AI output before UI rendering.
 */
export function sanitizeHtmlTags(text) {
  if (!text) return text;
  let processed = text;
  
  // Fix sub/sup tags: find each opening tag and ensure closing tag is right after the symbol
  ['sub', 'sup'].forEach(tag => {
    const openTag = `<${tag}>`;
    const closeTag = `</${tag}>`;
    
    // Check for orphaned tags at the very end of string
    if (processed.includes(openTag) && !processed.includes(closeTag)) {
      // Find the tag and close it immediately after the next non-whitespace chunk
      const regex = new RegExp(`${openTag}([^\\s,.;:!()]+)`, 'g');
      processed = processed.replace(regex, `${openTag}$1${closeTag}`);
      
      // If still exists (e.g. at end of string with nothing after it)
      if (processed.endsWith(openTag)) {
        processed = processed.substring(0, processed.length - openTag.length);
      }
    }

    let result = '';
    let remaining = processed;
    
    while (remaining.includes(openTag)) {
      const openIdx = remaining.indexOf(openTag);
      
      // Add everything before this tag to result
      result += remaining.substring(0, openIdx);
      remaining = remaining.substring(openIdx + openTag.length);
      
      // Check if there's a closing tag
      const closeIdx = remaining.indexOf(closeTag);
      
      if (closeIdx === -1) {
        // No closing tag at all — find symbol content and close immediately
        const symbolMatch = remaining.match(/^([^\s,.;:!()]+)/);
        if (symbolMatch) {
          result += openTag + symbolMatch[1] + closeTag;
          remaining = remaining.substring(symbolMatch[1].length);
        } else {
          // Just remove the orphaned tag if no content follows
          // Or keep it if we can't safely close it (risky)
          // Let's just not add anything and discard the open tag
        }
      } else {
        // There IS a closing tag — check if content between tags is too long
        const content = remaining.substring(0, closeIdx);
        
        if (content.length <= 15 && !content.includes(' ') && !content.includes('\n')) {
          // Content is short and clean — tag is properly placed
          result += openTag + content + closeTag;
          remaining = remaining.substring(closeIdx + closeTag.length);
        } else {
          // Content is too long or contains spaces — closing tag is misplaced!
          const symbolMatch = content.match(/^([^\s,.;:!()]+)/);
          if (symbolMatch) {
            result += openTag + symbolMatch[1] + closeTag;
            const afterSymbol = content.substring(symbolMatch[1].length);
            remaining = afterSymbol + remaining.substring(closeIdx + closeTag.length);
          } else {
            // Cannot find a symbol, just strip this pair
            result += content;
            remaining = remaining.substring(closeIdx + closeTag.length);
          }
        }
      }
    }
    
    processed = result + remaining;
  });

  // Final catch for accidental tags at the end of the text
  processed = processed.replace(/<(sub|sup)>$/, '');

  // Fix punctuation leakage: <sup>2,</sup> -> <sup>2</sup>,
  processed = processed.replace(/(<sub>|<sup>)([^<]*?)([.,;])(<\/sub>|<\/sup>)/g, '$1$2$4$3');
  
  // Fix double closing tags
  processed = processed.replace(/<\/sup><\/sup>/g, '</sup>')
                       .replace(/<\/sub><\/sub>/g, '</sub>');

  return processed;
}
