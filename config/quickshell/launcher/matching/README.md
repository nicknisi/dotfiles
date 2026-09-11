# Smart Match runtime

The default is **Voice and text**, using **Small (2M)**. Settings are under
Keystroke Settings > Matching. **Only voice** leaves typed queries on the ordinary
matcher. **Off** terminates the helper (including an in-progress installation),
clears pending results and releases the model; downloaded files remain for reuse.
**Large (8M)** needs its own model download through Retry when it is not cached. Both models run on CPU.
An idle helper also exits after two minutes and reloads on the next eligible query.

The launcher first tries verified cached models and runtimes with `--offline`.
Missing files keep lexical search working and add a Retry Smart Match row to the
Matching settings screen. Retry explicitly permits setup and its network downloads.
Off cancels setup and revokes that permission. Setup runs outside the UI process,
under the user's account, with no system package changes. The portable checkout
intentionally omits a prebuilt engine. First setup uses an available `cargo` or
installs a user-scoped Rust toolchain through `mise`. Building requires a C linker.
There is no Python fallback. Failed setup leaves ordinary fuzzy search available.
`luajit helpers/matching-start.lua --model small --install-only` explicitly prepares
a model without enabling or restarting the launcher. Use `--offline` for checks
that must not provision anything.

## Engine

`helpers/matching-start.lua` first verifies or downloads the three model files
(`config.json`, `tokenizer.json`, `model.safetensors`) for the pinned revision
straight from Hugging Face, comparing each against the SHA-256 digest recorded in
the script; a file cached by an earlier release's `huggingface_hub` layout is reused
when its digest matches. It then serves the model through the first of:

1. `matching/bin/keystroke-matching`, if separately built from this checkout.
   The portable checkout does not ship this binary. Its manifest
   (`keystroke-matching.json`) records the architecture, source fingerprint and
   binary SHA-256. All three must match before the binary can run.
   `matching/engine/build-prebuilt.sh` builds it after an engine change.
2. `matching/engine`, the Rust source, built once per source revision with `cargo`
   with `--locked` into the data directory when the separately built binary does
   not apply. Its direct dependencies are serde, serde_json, unicode-normalization
   and unicode_categories. Only the finished binary is kept.

The engine is not a deep-learning framework: a Model2Vec model is one embedding
row per vocabulary token, and a text's vector is the mean of its token rows. The
engine implements the BERT WordPiece tokenizer as `tokenizers` performs it
(BertNormalizer, BertPreTokenizer, greedy WordPiece; `[UNK]` dropped as Model2Vec
does), reads the F32 table from the safetensors file and ranks by cosine.
Rust unit tests cover tokenizer special tokens, normalization, token limits,
model validation and protocol errors. `tests/matching_live.py` checks a prepared
model offline. During the migration, 73,494 tokenizer inputs matched the previous
Python implementation, including Unicode and special-token cases.

On this machine, five-run medians with the small model were 34 ms to ready through
the Lua helper and 16 MiB resident after indexing 1,500 documents. The previous
Python path took 222 ms and 88 MiB.

The engine and models live in
`${XDG_DATA_HOME:-~/.local/share}/keystroke/matching/` under `engine/<source hash>/`
and `models/<name>/<revision>/`. Model revisions and digests are fixed in
`helpers/matching-start.lua`. Subsequent loading is local-only. No query or catalog
text is sent to a remote inference service or saved by the worker. Explicit setup
may download model files, the Rust toolchain through mise, and the crates named in
`Cargo.lock`. The old Python environment is no longer used.

A single JSON-lines worker keeps normalized static vectors in memory. Catalog
updates reuse unchanged vectors and evict removed documents. Requests contain
only stable IDs and metadata, not executable actions. Replies contain IDs and
similarity scores. The host filters availability and scope before sending metadata
and maps replies back onto fresh provider rows. Each query/catalog/model has its
own request key; old responses cannot populate a newer query. Only the latest
queued query is kept while a request is in flight. The catalog travels with a
request only when its digest changed.

The host retains exact matching, adds bounded typo recovery and a conditional
Chrome-to-Chromium alias, and then adds semantic suggestions above fallbacks but
below exact hits before applying learned query preferences. It filters negation, command family, volume/brightness direction,
start/stop and contradictory on/off setters. A toggle is still presented as a
**Toggle**: unknown current state is never treated as a guaranteed on/off setter.
Equivalent commands are deduplicated while retaining confirmations. Results never
run automatically. The host port excludes the calculator.

`descriptions.json` is the frozen GPT-5.6 Terra annotation pass: 618 one-sentence
intent descriptions, produced from installed metadata without access to the test
queries. `description-keys.json` binds the descriptions to their original titles
and fingerprints of action/target definitions. Changed/custom/absent entries fall back to live
metadata. App IDs accept the AppLibrary's optional `.desktop` suffix. Community
providers can supply a live `catalog(ctx)` and their own `intentDescription`.
The shipped map does not create or install its catalog's apps or hotkeys.

The default ~8 MB 2M model has 64-dimensional vectors; the ~31 MB 8M model has
256-dimensional vectors. The compiled engine holds the table in memory. Neither
similarity nor a fixed threshold proves intent. This remains a suggestions system
with explicit selection and existing confirmation rules.

Model2Vec and the POTION models are MIT licensed:
https://github.com/MinishLab/model2vec
https://huggingface.co/minishlab/potion-base-2M
https://huggingface.co/minishlab/potion-base-8M

Model revisions:
- small: `389b9f64be5aa4ae7a6bc6fe95ef20ce485ae5da`
- large: `bf8b056651a2c21b8d2565580b8569da283cab23`
