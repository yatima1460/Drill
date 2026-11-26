# Unicode filename matching

Drill lowercases the whole filename with the pinned Rust toolchain before canonical decomposition and removal of all Unicode marks. This preserves context-sensitive lowercase forms such as Greek final sigma. Linguistic compatibility substitutions remain distinct.

The generator recursively expands canonical mappings from Unicode 18.0.0 and drops terminal characters from general categories Mn, Mc and Me. It checks that every nonzero canonical combining class belongs to one of those categories. Canonical ordering can therefore only swap characters that disappear from the output. Concatenating the per-scalar projections produces the same result for any input string. The runtime decomposes all 11,172 Hangul syllables using the standard jamo arithmetic. [Unicode normalization algorithms](https://www.unicode.org/reports/tr15/)

The 2,107 sorted ranges in `ranges.bin` hold inclusive endpoints followed by the byte offset and length of the corresponding UTF-8 string in `replacements.bin`. Unlisted scalars pass through. Regenerate from the repository root using the [official UnicodeData.txt](https://www.unicode.org/Public/18.0.0/ucd/UnicodeData.txt). The generator verifies the download against its pinned SHA-256 digest. The [Unicode license](../../../../src/assets/emoji/LICENSE-UNICODE) accompanies the generated data.

```sh
python3 scripts/update-search-normalization.py /path/to/UnicodeData.txt
```

## Compare against the previous implementation

Run the oracle with a temporary Cargo manifest so that the reference library stays outside the application and its tests. Pass the [Unicode 18 normalization conformance file](https://www.unicode.org/Public/18.0.0/ucd/NormalizationTest.txt), SHA-256 `25a50d816764b04abfb4a646d3eb2b2a803284c3873d9a06757b94fe4513dde3`.

```sh
corpus=/path/to/NormalizationTest.txt
printf '%s  %s\n' 25a50d816764b04abfb4a646d3eb2b2a803284c3873d9a06757b94fe4513dde3 "$corpus" | shasum -a 256 -c -
oracle=$(mktemp -d)
cat > "$oracle/Cargo.toml" <<EOF
[package]
name = "drill-normalization-oracle"
version = "0.0.0"
edition = "2021"

[[bin]]
name = "oracle"
path = "$PWD/crates/drill-core/src/normalization/oracle.rs"

[dependencies]
unicode-normalization = "=0.1.26"
EOF
cargo run --release --manifest-path "$oracle/Cargo.toml" -- "$corpus"
```

The oracle compares the complete adapter on every Unicode scalar, every scalar in three combining-mark and Greek sigma contexts, and all five columns of every conformance row.
