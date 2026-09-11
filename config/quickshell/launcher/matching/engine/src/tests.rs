use super::*;
use serde_json::json;

#[test]
fn null_rows_rejected_and_catalog_preserved() {
    let mut index = Index::new(Model::fixture());
    assert_eq!(respond(&mut index, json!({"id":1,"query":"a","rows":[{"id":"a","text":"a"}]}))["type"], "result");
    for rows in [json!(null), json!({}), json!([{}]), json!([{"id":"a","text":"a"},{"id":"a","text":"b"}])] {
        let answer = respond(&mut index, json!({"id":2,"query":"a","rows":rows}));
        assert_eq!(answer["type"], "error");
        assert_eq!(answer["id"], 2);
        assert_eq!(index.ids, vec!["a"]);
    }
    assert_eq!(respond(&mut index, json!({"id":3,"query":"a"}))["matches"][0]["id"], "a");
    assert_eq!(respond(&mut index, json!({"id":4,"query":"a","rows":[]}))["matches"], json!([]));
    assert!(index.cache.is_empty());
}

#[test]
fn request_types_errors_and_unicode_limits() {
    let mut index = Index::new(Model::fixture());
    for request in [json!([]), json!([1,"a",[]]), json!(null), json!({"id":true}), json!({"id":1.5}), json!({})] {
        assert_eq!(respond(&mut index, request)["type"], "error");
    }
    assert_eq!(respond(&mut index, json!({"id":u64::MAX,"query":""}))["id"], u64::MAX);
    let id = "é".repeat(MAX_ID);
    assert!(index.update(json!([{"id":id,"text":"a"}])).is_ok());
    assert!(index.update(json!([{"id":"é".repeat(MAX_ID+1),"text":"a"}])).is_err());
    assert!(index.query(&json!("é".repeat(MAX_QUERY))).is_ok());
    assert!(index.query(&json!("é".repeat(MAX_QUERY+1))).is_err());
    assert!(index.query(&json!("\u{1c}\u{1f}\u{0085}")).unwrap().is_empty());
    assert!(index.query(&json!(null)).is_err());
}

#[test]
fn stable_top_thirty_cache_reuse_and_eviction() {
    let mut index = Index::new(Model::fixture());
    let rows: Vec<_> = (0..40).map(|i| json!({"id":i.to_string(),"text":"a"})).collect();
    index.update(json!(rows)).unwrap();
    assert_eq!(index.cache.len(), 1);
    let hits = index.query(&json!("unknown")).unwrap();
    assert_eq!(hits.len(), 30);
    for (i, hit) in hits.iter().enumerate() { assert_eq!(hit.id, i.to_string()); assert_eq!(hit.score, 0.); }
    index.update(json!([{"id":"changed","text":"b"}])).unwrap();
    assert!(!index.cache.contains_key("a"));
    assert_eq!(index.query(&json!("b")).unwrap()[0].score, 1.);
    assert!(index.update(json!(vec![json!({"id":"x","text":"a"}); MAX_ROWS+1])).is_err());
}

#[test]
fn request_reader_is_bounded_even_without_newline() {
    let mut reader = io::Cursor::new(vec![b'x'; MAX_LINE * 2]);
    let mut line = Vec::new();
    assert_eq!(read_line(&mut reader, &mut line).unwrap_err(), "Matching request is too large");
    assert_eq!(line.len(), MAX_LINE + 1);
    assert_eq!(reader.position(), (MAX_LINE + 1) as u64);
    let mut reader = io::Cursor::new(b"{}\n{}".to_vec());
    assert_eq!(read_line(&mut reader, &mut line).unwrap(), 3);
    assert_eq!(read_line(&mut reader, &mut line).unwrap(), 2);
    assert_eq!(read_line(&mut reader, &mut line).unwrap(), 0);
}
