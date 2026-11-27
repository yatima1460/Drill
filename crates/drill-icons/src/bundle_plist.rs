//! Read the one top-level Info.plist string used to locate a bundle's icon.
const ICON_KEY: &str = "CFBundleIconFile";
const MAX_NAME_BYTES: usize = 255;

pub(super) fn icon_file(bytes: &[u8]) -> Option<String> {
    if bytes.starts_with(b"bplist00") {
        binary_icon_file(bytes)
    } else {
        xml_icon_file(std::str::from_utf8(bytes).ok()?)
    }
}

// Tokenize a bounded UTF-8 plist. Track nesting so a document type's icon or a
// string in a comment cannot be mistaken for the application's icon.
fn xml_icon_file(mut xml: &str) -> Option<String> {
    let mut stack = Vec::new();
    let mut want_icon = false;
    loop {
        let (text, markup) = xml.split_once('<')?;
        if let Some(comment) = markup.strip_prefix("!--") {
            if matches!(stack.last(), Some(&"key" | &"string")) {
                return None;
            }
            xml = comment.split_once("-->")?.1;
            continue;
        }
        let (tag, rest) = markup.split_once('>')?;
        xml = rest;
        if stack.is_empty() && (tag.starts_with("?xml ") || tag.starts_with("!DOCTYPE plist ")) {
            // Ignore the declaration. Never resolve a DTD or interpret a subset.
            if tag.contains(['[', '<']) {
                return None;
            }
            continue;
        }
        if let Some(end) = tag.strip_prefix('/') {
            if stack.pop()? != end {
                return None;
            }
            if stack == ["plist", "dict"] {
                if end == "key" {
                    want_icon = text == ICON_KEY;
                } else if want_icon && end == "string" {
                    return xml_name(text);
                }
            }
        } else {
            let (name, empty) = match tag.trim_end().strip_suffix('/') {
                Some(name) => (name.trim_end(), true),
                None => (tag, false),
            };
            let name = if stack.is_empty() && name.starts_with("plist ") {
                "plist"
            } else {
                name
            };
            if !name.bytes().all(|byte| byte.is_ascii_alphabetic())
                || matches!(stack.last(), Some(&"key" | &"string"))
                || (stack.is_empty() && name != "plist")
                || (stack == ["plist"] && name != "dict")
                || (want_icon && stack == ["plist", "dict"] && (empty || name != "string"))
                || stack.len() >= 32
            {
                return None;
            }
            if !empty {
                stack.push(name);
            }
        }
    }
}

fn xml_name(mut text: &str) -> Option<String> {
    let mut name = String::new();
    while let Some((prefix, entity)) = text.split_once('&') {
        if prefix.len() + name.len() >= MAX_NAME_BYTES {
            return None;
        }
        name.push_str(prefix);
        let (reference, rest) = entity.split_once(';')?;
        name.push(match reference {
            "amp" => '&',
            "apos" => '\'',
            "quot" => '"',
            "lt" => '<',
            "gt" => '>',
            _ => return None,
        });
        text = rest;
    }
    if text.len() + name.len() > MAX_NAME_BYTES {
        return None;
    }
    name.push_str(text);
    Some(name)
}

// In bplist00 only the root dictionary's key/value references are needed.
// Follow no nested objects. Reject overflowing offsets before indexing.
fn binary_icon_file(bytes: &[u8]) -> Option<String> {
    let (body, trailer) = bytes.split_at_checked(bytes.len().checked_sub(32)?)?;
    let offset_size = usize::from(trailer[6]);
    let ref_size = usize::from(trailer[7]);
    if !(1..=8).contains(&offset_size) || !(1..=8).contains(&ref_size) {
        return None;
    }
    let object_count = unsigned(&trailer[8..16])?;
    let root = unsigned(&trailer[16..24])?;
    let (objects, offsets) = body.split_at_checked(unsigned(&trailer[24..])?)?;
    if object_count.checked_mul(offset_size)? != offsets.len() {
        return None;
    }
    let object = |index: usize| {
        let offset = unsigned(
            offsets
                .get(index.checked_mul(offset_size)?..)?
                .get(..offset_size)?,
        )?;
        if offset < 8 {
            return None;
        }
        binary_object(objects.get(offset..)?)
    };
    let (kind, count, refs) = object(root)?;
    if kind != 0xd || count > 4096 {
        return None;
    }
    let (keys, values) = refs.split_at_checked(count.checked_mul(ref_size)?)?;
    let values = values.get(..keys.len())?;
    for (key, value) in keys
        .chunks_exact(ref_size)
        .zip(values.chunks_exact(ref_size))
    {
        let (kind, length, data) = object(unsigned(key)?)?;
        if length == ICON_KEY.len() && binary_string(kind, length, data)?.as_str() == ICON_KEY {
            let (kind, length, data) = object(unsigned(value)?)?;
            return binary_string(kind, length, data);
        }
    }
    None
}

fn binary_object(bytes: &[u8]) -> Option<(u8, usize, &[u8])> {
    let (&marker, mut data) = bytes.split_first()?;
    let mut length = usize::from(marker & 15);
    if length == 15 {
        let (&integer, rest) = data.split_first()?;
        if !(0x10..=0x13).contains(&integer) {
            return None;
        }
        let (encoded, rest) = rest.split_at_checked(1 << (integer - 0x10))?;
        length = unsigned(encoded)?;
        data = rest;
    }
    Some((marker >> 4, length, data))
}

fn unsigned(bytes: &[u8]) -> Option<usize> {
    let mut word = [0; 8];
    word.get_mut(8_usize.checked_sub(bytes.len())?..)?
        .copy_from_slice(bytes);
    usize::try_from(u64::from_be_bytes(word)).ok()
}

fn binary_string(kind: u8, length: usize, data: &[u8]) -> Option<String> {
    if length > MAX_NAME_BYTES {
        return None;
    }
    match kind {
        5 => {
            let text = data.get(..length)?;
            std::str::from_utf8(text)
                .ok()
                .filter(|name| name.is_ascii())
                .map(str::to_owned)
        }
        6 => {
            let units = data
                .get(..length * 2)?
                .as_chunks::<2>()
                .0
                .iter()
                .copied()
                .map(u16::from_be_bytes);
            char::decode_utf16(units)
                .collect::<Result<String, _>>()
                .ok()
        }
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn xml_selects_the_root_key_and_ignores_comment_and_nested_keys() {
        let xml = br#"<?xml version="1.0"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0"><dict><!-- <key>CFBundleIconFile</key><string>comment</string> -->
            <key>CFBundleDocumentTypes</key><array><dict><key>CFBundleIconFile</key><string>nested</string></dict></array>
            <key>CFBundleIconFile</key><string>Mac &amp; Cheese.icns</string></dict></plist>"#;
        assert_eq!(icon_file(xml).as_deref(), Some("Mac & Cheese.icns"));
    }

    #[test]
    fn xml_refuses_entities_and_nonstring_values() {
        for value in [
            "<string>&xxe;</string>",
            "<array/>",
            "<dict><string>bad</string></dict>",
        ] {
            let xml = format!("<plist><dict><key>CFBundleIconFile</key>{value}</dict></plist>");
            assert_eq!(icon_file(xml.as_bytes()), None);
        }
        assert!(icon_file(b"<!DOCTYPE plist [<!ENTITY x SYSTEM 'file:///test'>]><plist><dict><key>CFBundleIconFile</key><string>good</string></dict></plist>").is_none());
    }

    #[test]
    fn binary_reads_top_level_unicode_value_and_rejects_invalid_references() {
        // Root dictionary (object 0), ASCII key (1), UTF-16BE string (2).
        let mut bytes =
            b"bplist00\xd1\x01\x02\x5f\x10\x10CFBundleIconFile\x62\x00A\x26\x05\x08\x0b\x1e"
                .to_vec();
        let mut trailer = [0; 32];
        trailer[6] = 1;
        trailer[7] = 1;
        trailer[15] = 3;
        trailer[31] = 35;
        bytes.extend_from_slice(&trailer);
        assert_eq!(icon_file(&bytes).as_deref(), Some("A★"));
        for end in 0..bytes.len() {
            assert!(icon_file(&bytes[..end]).is_none());
        }
        bytes[10] = 255;
        assert!(icon_file(&bytes).is_none());
    }
}
