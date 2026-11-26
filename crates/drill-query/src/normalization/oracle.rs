use std::{env, fs};
use unicode_normalization::{char::is_combining_mark, UnicodeNormalization};

#[path = "../normalization.rs"]
mod candidate;

fn oracle(s: &str) -> String {
    s.to_lowercase()
        .nfd()
        .filter(|c| !is_combining_mark(*c))
        .collect()
}

fn check(s: &str) {
    assert_eq!(candidate::normalized(s), oracle(s), "{s:?}");
}

fn main() {
    assert_eq!(unicode_normalization::UNICODE_VERSION, (18, 0, 0));
    let mut scalars = 0;
    let mut contexts = 0;
    let mut buf = String::new();
    for ch in (0..=0x10ffff).filter_map(char::from_u32) {
        let mut utf8 = [0; 4];
        check(ch.encode_utf8(&mut utf8));
        scalars += 1;
        for (prefix, suffix) in [
            ("ΟΣ", "ΣΑ"),
            ("Α", "Σ"),
            ("\u{345}\u{315}", "\u{316}\u{301}"),
        ] {
            buf.clear();
            buf.push_str(prefix);
            buf.push(ch);
            buf.push_str(suffix);
            check(&buf);
            contexts += 1;
        }
    }
    let data =
        fs::read_to_string(env::args_os().nth(1).expect("pass NormalizationTest.txt")).unwrap();
    assert!(data.starts_with("# NormalizationTest-18.0.0.txt"));
    let mut records = 0;
    for row in data.lines() {
        let row = row.split('#').next().unwrap().trim();
        if row.is_empty() || row.starts_with('@') {
            continue;
        }
        let columns: Vec<String> = row
            .split_terminator(';')
            .map(|c| {
                c.split_ascii_whitespace()
                    .map(|hex| char::from_u32(u32::from_str_radix(hex, 16).unwrap()).unwrap())
                    .collect()
            })
            .collect();
        assert_eq!(columns.len(), 5);
        for column in columns {
            check(&column);
        }
        records += 1;
    }
    assert_eq!(records, 20_171, "incomplete conformance file");
    println!("{scalars} Unicode scalars, {contexts} contextual strings, {records} official conformance rows ({} sequences) agree with the locked reference", records * 5);
}
