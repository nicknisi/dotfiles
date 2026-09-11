//! BERT WordPiece tokenization as `tokenizers` performs it for the POTION
//! models: BertNormalizer (clean text, pad CJK, strip accents, lowercase),
//! BertPreTokenizer (whitespace, isolated punctuation) and greedy WordPiece.
//! Special tokens are never added; the caller drops `[UNK]` like Model2Vec.

use std::collections::HashMap;
use unicode_categories::UnicodeCategories;
use unicode_normalization::UnicodeNormalization;

pub struct Tokenizer {
    vocab: HashMap<String, u32>,
    unk_id: u32,
    prefix: String,
    max_chars: usize,
    lowercase: bool,
    strip_accents: bool,
    clean_text: bool,
    handle_chinese: bool,
    added_tokens: Vec<(String, u32)>,
}

fn is_whitespace(c: char) -> bool {
    matches!(c, '\t' | '\n' | '\r') || c.is_whitespace()
}

fn is_control(c: char) -> bool {
    !matches!(c, '\t' | '\n' | '\r') && c.is_other()
}

fn is_chinese_char(c: char) -> bool {
    matches!(c as u32,
        0x4E00..=0x9FFF | 0x3400..=0x4DBF | 0x20000..=0x2A6DF | 0x2A700..=0x2B73F |
        0x2B740..=0x2B81F | 0x2B920..=0x2CEAF | 0xF900..=0xFAFF | 0x2F800..=0x2FA1F)
}

fn is_bert_punc(c: char) -> bool {
    c.is_ascii_punctuation() || c.is_punctuation()
}

impl Tokenizer {
    pub fn from_json(text: &str) -> Result<Tokenizer, String> {
        let json: serde_json::Value = serde_json::from_str(text).map_err(|e| format!("tokenizer.json: {e}"))?;
        let model = &json["model"];
        if model["type"] != "WordPiece" { return Err("tokenizer.json: only WordPiece models are supported".into()); }
        let vocab_json = model["vocab"].as_object().ok_or("tokenizer.json: missing vocab")?;
        let mut vocab = HashMap::with_capacity(vocab_json.len());
        for (token, id) in vocab_json {
            let id = id.as_u64().and_then(|n| u32::try_from(n).ok()).ok_or("tokenizer.json: bad vocab id")?;
            vocab.insert(token.clone(), id);
        }
        let unk = model["unk_token"].as_str().unwrap_or("[UNK]");
        let unk_id = *vocab.get(unk).ok_or("tokenizer.json: unk token missing from vocab")?;
        let normalizer = &json["normalizer"];
        if normalizer["type"] != "BertNormalizer" { return Err("tokenizer.json: only BertNormalizer is supported".into()); }
        if json["pre_tokenizer"]["type"] != "BertPreTokenizer" { return Err("tokenizer.json: only BertPreTokenizer is supported".into()); }
        let lowercase = normalizer["lowercase"].as_bool().unwrap_or(true);
        let mut added_tokens = Vec::new();
        if let Some(tokens) = json["added_tokens"].as_array() {
            for token in tokens {
                let content = token["content"].as_str().filter(|s| !s.is_empty()).ok_or("tokenizer.json: bad added token")?;
                let id = token["id"].as_u64().and_then(|n| u32::try_from(n).ok()).ok_or("tokenizer.json: bad added token id")?;
                if vocab.get(content) != Some(&id) || ["single_word", "lstrip", "rstrip", "normalized"].iter().any(|k| token[k].as_bool() != Some(false)) {
                    return Err("tokenizer.json: unsupported added token".into());
                }
                added_tokens.push((content.to_string(), id));
            }
        }
        Ok(Tokenizer {
            vocab,
            unk_id,
            prefix: model["continuing_subword_prefix"].as_str().unwrap_or("##").to_string(),
            max_chars: model["max_input_chars_per_word"].as_u64().unwrap_or(100) as usize,
            lowercase,
            strip_accents: normalizer["strip_accents"].as_bool().unwrap_or(lowercase),
            clean_text: normalizer["clean_text"].as_bool().unwrap_or(true),
            handle_chinese: normalizer["handle_chinese_chars"].as_bool().unwrap_or(true),
            added_tokens,
        })
    }

    pub fn unk_id(&self) -> u32 { self.unk_id }

    pub fn validate_rows(&self, rows: usize) -> Result<(), String> {
        let ids: std::collections::HashSet<_> = self.vocab.values().copied().collect();
        if self.vocab.len() != rows || ids.len() != rows || ids.iter().any(|&id| id as usize >= rows) {
            return Err("tokenizer.json: vocabulary does not match embeddings".into());
        }
        Ok(())
    }

    pub fn median_token_length(&self) -> usize {
        let mut lengths: Vec<_> = self.vocab.keys().map(|s| s.chars().count()).collect();
        lengths.sort_unstable();
        (lengths[(lengths.len() - 1) / 2] + lengths[lengths.len() / 2]) / 2
    }

    fn normalize(&self, text: &str) -> String {
        let mut out: Vec<char> = Vec::with_capacity(text.len());
        for c in text.chars() {
            if self.clean_text {
                if c == '\0' || c == '\u{fffd}' || is_control(c) { continue; }
                if is_whitespace(c) { out.push(' '); continue; }
            }
            if self.handle_chinese && is_chinese_char(c) { out.push(' '); out.push(c); out.push(' '); continue; }
            out.push(c);
        }
        let mut s: String = out.into_iter().collect();
        if self.strip_accents { s = s.nfd().filter(|c| !c.is_mark_nonspacing()).collect(); }
        if self.lowercase { s = s.chars().flat_map(|c| c.to_lowercase()).collect(); }
        s
    }

    /// Words as the pre-tokenizer yields them: whitespace removed, every
    /// punctuation character isolated.
    fn words<'a>(&self, text: &'a str) -> Vec<&'a str> {
        let mut out = Vec::new();
        for chunk in text.split(char::is_whitespace) {
            if chunk.is_empty() { continue; }
            let mut start = 0;
            for (i, c) in chunk.char_indices() {
                if is_bert_punc(c) {
                    if i > start { out.push(&chunk[start..i]); }
                    out.push(&chunk[i..i + c.len_utf8()]);
                    start = i + c.len_utf8();
                }
            }
            if start < chunk.len() { out.push(&chunk[start..]); }
        }
        out
    }

    fn word_pieces(&self, word: &str, out: &mut Vec<u32>) {
        if word.chars().count() > self.max_chars { out.push(self.unk_id); return; }
        let mut pieces = Vec::new();
        let mut start = 0;
        while start < word.len() {
            let mut end = word.len();
            let mut found = None;
            while start < end {
                let candidate = if start > 0 { format!("{}{}", self.prefix, &word[start..end]) } else { word[start..end].to_string() };
                if let Some(&id) = self.vocab.get(&candidate) { found = Some(id); break; }
                end -= word[start..end].chars().last().map_or(1, |c| c.len_utf8());
            }
            match found {
                Some(id) => { pieces.push(id); start = end; }
                None => { out.push(self.unk_id); return; }
            }
        }
        out.extend(pieces);
    }

    fn encode_plain(&self, text: &str, ids: &mut Vec<u32>) {
        let normalized = self.normalize(text);
        for word in self.words(&normalized) { self.word_pieces(word, ids); }
    }

    pub fn encode(&self, mut text: &str) -> Vec<u32> {
        let mut ids = Vec::new();
        // Literal added tokens are isolated before normalization, even when
        // add_special_tokens=false. That flag only disables the post-processor.
        while !text.is_empty() {
            let found = self.added_tokens.iter().filter_map(|(token, id)| text.find(token).map(|at| (at, token, id)))
                .min_by(|a, b| a.0.cmp(&b.0).then(b.1.len().cmp(&a.1.len())));
            if let Some((at, token, id)) = found {
                self.encode_plain(&text[..at], &mut ids);
                ids.push(*id);
                text = &text[at + token.len()..];
            } else {
                self.encode_plain(text, &mut ids);
                break;
            }
        }
        ids
    }
}
