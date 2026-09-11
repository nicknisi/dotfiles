//! A Model2Vec static model: one F32 embedding row per vocabulary entry read
//! from `model.safetensors`, mean-pooled over the token ids of a text.

use std::fs;
use std::path::Path;

use crate::tokenizer::Tokenizer;

pub struct Model {
    tokenizer: Tokenizer,
    embeddings: Vec<f32>,
    rows: usize,
    max_chars: usize,
    pub dim: usize,
}

fn read_safetensors(path: &Path) -> Result<(Vec<f32>, usize, usize), String> {
    let bytes = fs::read(path).map_err(|e| format!("{}: {e}", path.display()))?;
    parse_safetensors(&bytes)
}

fn parse_safetensors(bytes: &[u8]) -> Result<(Vec<f32>, usize, usize), String> {
    if bytes.len() < 8 { return Err("model.safetensors: truncated header".into()); }
    let header_len = usize::try_from(u64::from_le_bytes(bytes[..8].try_into().unwrap())).map_err(|_| "model.safetensors: bad header length")?;
    if header_len > 1 << 20 || 8 + header_len > bytes.len() { return Err("model.safetensors: bad header length".into()); }
    let header: serde_json::Value = serde_json::from_slice(&bytes[8..8 + header_len]).map_err(|e| format!("model.safetensors header: {e}"))?;
    let tensor = header.get("embeddings").ok_or("model.safetensors: no embeddings tensor")?;
    if tensor["dtype"] != "F32" { return Err("model.safetensors: embeddings must be F32".into()); }
    let shape = tensor["shape"].as_array().ok_or("model.safetensors: bad shape")?;
    if shape.len() != 2 { return Err("model.safetensors: embeddings must be two-dimensional".into()); }
    let integer = |v: &serde_json::Value| v.as_u64().and_then(|n| usize::try_from(n).ok()).ok_or("model.safetensors: invalid dimension or offset");
    let rows = integer(&shape[0])?;
    let dim = integer(&shape[1])?;
    let offsets = tensor["data_offsets"].as_array().filter(|a| a.len() == 2).ok_or("model.safetensors: bad offsets")?;
    let start = (8 + header_len).checked_add(integer(&offsets[0])?).ok_or("model.safetensors: bad start offset")?;
    let end = (8 + header_len).checked_add(integer(&offsets[1])?).ok_or("model.safetensors: bad end offset")?;
    let size = rows.checked_mul(dim).and_then(|n| n.checked_mul(4)).ok_or("model.safetensors: tensor size overflow")?;
    if rows == 0 || dim == 0 || end > bytes.len() || end.checked_sub(start) != Some(size) { return Err("model.safetensors: tensor size mismatch".into()); }
    let data: Vec<f32> = bytes[start..end].chunks_exact(4).map(|c| f32::from_le_bytes([c[0], c[1], c[2], c[3]])).collect();
    if data.iter().any(|v| !v.is_finite()) { return Err("model.safetensors: non-finite embedding".into()); }
    Ok((data, rows, dim))
}

impl Model {
    #[cfg(test)]
    pub fn fixture() -> Model {
        let tokenizer = Tokenizer::from_json(r##"{
            "model":{"type":"WordPiece","vocab":{"[UNK]":0,"a":1,"b":2,"[CLS]":3,"é":4},"unk_token":"[UNK]"},
            "normalizer":{"type":"BertNormalizer"},"pre_tokenizer":{"type":"BertPreTokenizer"},
            "added_tokens":[{"id":3,"content":"[CLS]","single_word":false,"lstrip":false,"rstrip":false,"normalized":false}]
        }"##).unwrap();
        let max_chars = 512 * tokenizer.median_token_length();
        Model { tokenizer, embeddings: vec![0.,0., 1.,0., 0.,1., 1.,1., 1.,0.], rows: 5, max_chars, dim: 2 }
    }

    pub fn load(dir: &Path) -> Result<Model, String> {
        let config: serde_json::Value = serde_json::from_str(&fs::read_to_string(dir.join("config.json")).map_err(|e| format!("config.json: {e}"))?)
            .map_err(|e| format!("config.json: {e}"))?;
        if config["model_type"] != "model2vec" { return Err("config.json: not a model2vec model".into()); }
        let tokenizer = Tokenizer::from_json(&fs::read_to_string(dir.join("tokenizer.json")).map_err(|e| format!("tokenizer.json: {e}"))?)?;
        let (embeddings, rows, dim) = read_safetensors(&dir.join("model.safetensors"))?;
        tokenizer.validate_rows(rows)?;
        let max_chars = 512 * tokenizer.median_token_length();
        Ok(Model { tokenizer, embeddings, rows, max_chars, dim })
    }

    pub fn tokenize(&self, text: &str) -> Vec<u32> {
        let unk = self.tokenizer.unk_id();
        self.tokenizer.encode(text).into_iter().filter(|&id| id != unk).collect()
    }

    /// Mean of the token vectors, L2-normalized; all zeros for a text without
    /// known tokens (which then scores 0 against everything).
    pub fn embed(&self, text: &str) -> Vec<f32> {
        let mut out = vec![0f32; self.dim];
        // StaticModel.encode defaults to 512 known tokens and first clips the
        // input to 512 * median vocabulary token length Unicode characters.
        let end = text.char_indices().nth(self.max_chars).map_or(text.len(), |(i, _)| i);
        let ids = self.tokenize(&text[..end]);
        let mut count = 0usize;
        for id in ids.into_iter().take(512) {
            let id = id as usize;
            if id >= self.rows { continue; }
            let row = &self.embeddings[id * self.dim..(id + 1) * self.dim];
            for (o, v) in out.iter_mut().zip(row) { *o += v; }
            count += 1;
        }
        if count == 0 { return out; }
        let scale = 1.0 / count as f32;
        for o in out.iter_mut() { *o *= scale; }
        let norm = out.iter().map(|v| v * v).sum::<f32>().sqrt();
        if norm > 1e-12 { for o in out.iter_mut() { *o /= norm; } }
        out
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn model2vec_token_and_character_truncation() {
        let mut model = Model::fixture();
        model.max_chars = 4096;
        assert_eq!(model.embed(&("a ".repeat(512) + "b")), vec![1., 0.]);
        model.max_chars = 512;
        assert_eq!(model.embed(&("a ".repeat(256) + "b")), vec![1., 0.]);
        // Character clipping, not UTF-8 byte clipping.
        model.max_chars = 3;
        assert!(model.embed("é b")[1] > 0.9);
    }

    #[test]
    fn literal_added_tokens_before_normalization() {
        let model = Model::fixture();
        assert_eq!(model.tokenize("a[CLS]b"), vec![1, 3, 2]);
        assert_eq!(model.tokenize("a[cls]b"), vec![1, 2]);
        assert_eq!(model.tokenize("unknown"), Vec::<u32>::new());
    }

    #[test]
    fn malformed_tensor_headers_return_errors_without_panics() {
        for (shape, offsets) in [
            (json!([1, 1]), json!([])), (json!([1, 1]), json!([4, 0])),
            (json!([1, 1]), json!([0, u64::MAX])), (json!([u64::MAX, 2]), json!([0, 4])),
            (json!([0, 1]), json!([0, 0])), (json!([1, 1]), json!([-1, 4])),
        ] {
            let header = json!({"embeddings":{"dtype":"F32","shape":shape,"data_offsets":offsets}}).to_string();
            let mut bytes = (header.len() as u64).to_le_bytes().to_vec();
            bytes.extend(header.as_bytes()); bytes.extend(1f32.to_le_bytes());
            assert!(parse_safetensors(&bytes).is_err());
        }
    }

    #[test]
    fn vocabulary_must_match_tensor() {
        assert!(Model::fixture().tokenizer.validate_rows(4).is_err());
        assert!(Model::fixture().tokenizer.validate_rows(5).is_ok());
    }
}
