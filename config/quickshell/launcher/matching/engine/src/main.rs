//! Keystroke Smart Match engine: a resident JSON-lines worker over local
//! Model2Vec embeddings. Requests carry stable IDs and descriptive text only;
//! replies carry IDs and similarity scores. Nothing here runs a command.
//!
//!   stdin  {"id": 1, "query": "open the browser", "rows": [{"id": "...", "text": "..."}]}
//!   stdout {"type": "result", "id": 1, "matches": [{"id": "...", "score": 0.83}]}
//!
//! `rows` replaces the catalog when present; unchanged texts keep their vectors.
//! Catalog updates are transactional. Invalid requests do not stop the worker.

mod model;
mod tokenizer;
#[cfg(test)]
mod tests;

use std::collections::HashMap;
use std::io::{self, BufRead, Read, Write};
use std::path::PathBuf;
use std::process;

use serde::Serialize;

use model::Model;

const MAX_LINE: usize = 4 * 1024 * 1024;
const MAX_ROWS: usize = 6000;
const MAX_ID: usize = 512;
const MAX_TEXT: usize = 4096;
const MAX_QUERY: usize = 1024;
const TOP: usize = 30;

#[derive(Serialize)]
struct Hit<'a> { id: &'a str, score: f32 }

fn emit(value: serde_json::Value) {
    let mut out = io::stdout().lock();
    let _ = serde_json::to_writer(&mut out, &value);
    let _ = out.write_all(b"\n");
    let _ = out.flush();
}

struct Index {
    model: Model,
    ids: Vec<String>,
    texts: Vec<String>,
    vectors: Vec<f32>,
    cache: HashMap<String, Vec<f32>>,
}

impl Index {
    fn new(model: Model) -> Index { Index { model, ids: Vec::new(), texts: Vec::new(), vectors: Vec::new(), cache: HashMap::new() } }

    fn update(&mut self, rows: serde_json::Value) -> Result<(), String> {
        let rows = rows.as_array().ok_or("Invalid matching catalog")?;
        if rows.len() > MAX_ROWS { return Err("Invalid matching catalog".into()); }
        let mut ids = Vec::with_capacity(rows.len());
        let mut texts = Vec::with_capacity(rows.len());
        let mut seen = std::collections::HashSet::with_capacity(rows.len());
        for row in rows {
            let (id, text) = match (row.get("id"), row.get("text")) {
                (Some(serde_json::Value::String(id)), Some(serde_json::Value::String(text))) => (id, text),
                _ => return Err("Invalid matching document".into()),
            };
            if id.is_empty() || !seen.insert(id.clone()) || id.chars().count() > MAX_ID || text.chars().count() > MAX_TEXT {
                return Err("Invalid matching document size or duplicate ID".into());
            }
            ids.push(id.clone());
            texts.push(text.clone());
        }
        if ids == self.ids && texts == self.texts { return Ok(()); }
        let dim = self.model.dim;
        let mut next: HashMap<String, Vec<f32>> = HashMap::with_capacity(texts.len());
        let mut vectors = Vec::with_capacity(texts.len() * dim);
        for text in &texts {
            if !next.contains_key(text) {
                let vector = match self.cache.remove(text) { Some(v) => v, None => self.model.embed(text) };
                next.insert(text.clone(), vector);
            }
            vectors.extend_from_slice(&next[text]);
        }
        self.cache = next;
        self.ids = ids;
        self.texts = texts;
        self.vectors = vectors;
        Ok(())
    }

    fn query(&self, query: &serde_json::Value) -> Result<Vec<Hit<'_>>, String> {
        let text = match query { serde_json::Value::String(s) => s, _ => return Err("Invalid matching query".into()) };
        if text.chars().count() > MAX_QUERY { return Err("Invalid matching query".into()); }
        // Python str.strip also treats the ASCII information separators as whitespace.
        if text.chars().all(|c| c.is_whitespace() || matches!(c, '\u{1c}'..='\u{1f}')) || self.ids.is_empty() { return Ok(Vec::new()); }
        let vector = self.model.embed(text);
        let dim = self.model.dim;
        let mut scored: Vec<(usize, f32)> = self.vectors.chunks_exact(dim).enumerate()
            .map(|(i, row)| (i, row.iter().zip(&vector).map(|(a, b)| a * b).sum::<f32>()))
            .filter(|(_, s)| s.is_finite())
            .collect();
        scored.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal).then(a.0.cmp(&b.0)));
        scored.truncate(TOP);
        Ok(scored.into_iter().map(|(i, score)| Hit { id: &self.ids[i], score }).collect())
    }
}

fn respond(index: &mut Index, request: serde_json::Value) -> serde_json::Value {
    let id = request.get("id").cloned().unwrap_or_default();
    // JSON booleans are not request IDs, even though Python treats bool as int.
    if !request.is_object() || !(id.is_i64() || id.is_u64()) {
        return serde_json::json!({"type": "error", "id": id, "message": "Invalid matching request"});
    }
    let outcome = match request.get("rows") { Some(rows) => index.update(rows.clone()), None => Ok(()) }
        .and_then(|_| index.query(&request["query"]).map(|hits| serde_json::to_value(hits).unwrap_or_default()));
    match outcome {
        Ok(matches) => serde_json::json!({"type": "result", "id": id, "matches": matches}),
        Err(message) => serde_json::json!({"type": "error", "id": id, "message": message}),
    }
}

fn read_line(reader: &mut impl BufRead, line: &mut Vec<u8>) -> Result<usize, String> {
    line.clear();
    let read = reader.take((MAX_LINE + 1) as u64).read_until(b'\n', line).map_err(|e| e.to_string())?;
    if read > MAX_LINE { return Err("Matching request is too large".into()); }
    Ok(read)
}

fn serve(model: Model) -> Result<(), String> {
    let mut index = Index::new(model);
    emit(serde_json::json!({"type": "ready"}));
    let stdin = io::stdin();
    let mut reader = stdin.lock();
    let mut line = Vec::new();
    loop {
        if read_line(&mut reader, &mut line)? == 0 { return Ok(()); }
        let answer = match serde_json::from_slice(&line) {
            Ok(request) => respond(&mut index, request),
            Err(_) => serde_json::json!({"type": "error", "id": null, "message": "Invalid matching request"}),
        };
        emit(answer);
    }
}

fn tokenize_stdin(model: &Model) {
    let stdin = io::stdin();
    let mut reader = stdin.lock();
    let mut line = Vec::new();
    while matches!(read_line(&mut reader, &mut line), Ok(n) if n > 0) {
        let text: String = match serde_json::from_slice(&line) { Ok(s) => s, Err(_) => break };
        emit(serde_json::Value::from(model.tokenize(&text)));
    }
}

fn main() {
    let mut args = std::env::args().skip(1);
    let mut dir: Option<PathBuf> = None;
    let mut name = String::from("small");
    let mut install_only = false;
    let mut tokenize = false;
    while let Some(arg) = args.next() {
        match arg.as_str() {
            "--model-dir" => dir = args.next().map(PathBuf::from),
            "--model" => name = args.next().unwrap_or_default(),
            "--install-only" => install_only = true,
            "--tokenize" => tokenize = true,
            _ => { emit(serde_json::json!({"type": "error", "message": format!("Unknown argument {arg}")})); process::exit(2); }
        }
    }
    let dir = match dir { Some(d) => d, None => { emit(serde_json::json!({"type": "error", "message": "--model-dir is required"})); process::exit(2); } };
    if !matches!(name.as_str(), "small" | "large") {
        emit(serde_json::json!({"type": "error", "message": "Invalid matching model"})); process::exit(2);
    }
    if !install_only && !tokenize { emit(serde_json::json!({"type": "status", "message": format!("Loading {name} matching model")})); }
    let model = match Model::load(&dir) {
        Ok(m) => m,
        Err(e) => { emit(serde_json::json!({"type": "error", "message": format!("Smart Match unavailable: {e}")})); process::exit(1); }
    };
    if tokenize { tokenize_stdin(&model); return; }
    if install_only { emit(serde_json::json!({"type": "installed", "model": name})); return; }
    if let Err(e) = serve(model) {
        emit(serde_json::json!({"type": "error", "message": format!("Smart Match unavailable: {e}")}));
        process::exit(1);
    }
}
