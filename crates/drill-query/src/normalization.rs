//! Search folds case, canonically decomposes filenames, and removes all Unicode marks.
// Each little-endian record holds inclusive u32 endpoints and a u16 UTF-8 offset and length.
const RANGES: &[[u8; 12]] = {
    let (records, remainder) = include_bytes!("normalization/ranges.bin").as_chunks();
    assert!(remainder.is_empty());
    records
};
const REPLACEMENTS: &str = include_str!("normalization/replacements.bin");

pub(crate) fn normalized(text: &str) -> String {
    // Keep whole-string lowercasing: the lowercase form of Greek sigma depends on context.
    let lowercase = text.to_lowercase();
    if lowercase.is_ascii() {
        return lowercase;
    }
    let mut output = String::with_capacity(lowercase.len());
    for c in lowercase.chars() {
        let point = u32::from(c);
        if c.is_ascii() {
            output.push(c);
        } else if (0xAC00..=0xD7A3).contains(&point) {
            // UAX #15, Hangul syllable decomposition into leading, vowel and trailing jamo.
            let syllable = point - 0xAC00;
            output.push(char::from_u32(0x1100 + syllable / (21 * 28)).unwrap());
            output.push(char::from_u32(0x1161 + syllable / 28 % 21).unwrap());
            let trailing = syllable % 28;
            if trailing != 0 {
                output.push(char::from_u32(0x11A7 + trailing).unwrap());
            }
        } else {
            let i =
                RANGES.partition_point(|r| u32::from_le_bytes(r[4..8].try_into().unwrap()) < point);
            if let Some(r) = RANGES
                .get(i)
                .filter(|r| u32::from_le_bytes(r[..4].try_into().unwrap()) <= point)
            {
                let offset = usize::from(u16::from_le_bytes(r[8..10].try_into().unwrap()));
                let len = usize::from(u16::from_le_bytes(r[10..12].try_into().unwrap()));
                output.push_str(&REPLACEMENTS[offset..offset + len]);
            } else {
                output.push(c);
            }
        }
    }
    output
}

#[cfg(test)]
mod tests {
    use super::normalized;

    #[test]
    fn folds_whole_strings_canonically_and_removes_all_mark_categories() {
        for (input, expected) in [
            ("NÔTÉS A\u{30a}", "notes a"),
            ("ΟΣ ΟΣΑ Ο\u{301}Σ", "ος οσα ος"),
            ("İstanbul", "istanbul"),
            ("x\u{315}\u{300}\u{93e}\u{20dd}\u{34f}", "x"),
            ("①ﬀ", "①ﬀ"),
            ("가각힣", "가각힣"),
            ("\u{16d6a}", "\u{16d63}\u{16d67}\u{16d67}"),
            ("\u{2f800}", "\u{4e3d}"),
        ] {
            assert_eq!(normalized(input), expected);
        }
    }
}
