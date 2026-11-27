//! Recognize whole supported sprite sequences while leaving ordinary text in its original runs.
//! The index contains only pictographs, keycaps, flags, and emoji components. Hangul syllable
//! and Indic conjunct boundaries cannot begin or end any of those sequences.

use super::{sprite, Sprite};

#[derive(Clone, Copy, PartialEq, Eq)]
enum Property {
    Other,
    Control,
    Extend,
    Joiner,
    Regional,
    Prepend,
    SpacingMark,
    Pictograph,
}

fn property(ch: char) -> Property {
    use Property::*;
    match ch {
        '\0'..='\u{1f}' | '\u{7f}' => Control,
        ' '..='~' => Other,
        _ => {
            const DATA: &[u8] = include_bytes!("../assets/emoji/sprite-boundaries.bin");
            let (ranges, []) = DATA.as_chunks::<4>() else {
                unreachable!("incomplete sprite boundary table");
            };
            let end = ranges.partition_point(|&word| u32::from_le_bytes(word) >> 3 <= ch as u32);
            let code = (ranges[end - 1][0] & 7) as usize;
            [
                Other,
                Control,
                Extend,
                Joiner,
                Regional,
                Prepend,
                SpacingMark,
                Pictograph,
            ][code]
        }
    }
}

#[derive(Clone, Copy)]
enum Prefix {
    StartOrControl,
    Other,
    Prepend,
    PictographWithExtends,
    PictographWithJoiner,
    OddRegionalRun,
}

impl Prefix {
    /// Consume one scalar and report whether its boundary could delimit a sprite.
    fn boundary(&mut self, next: Property) -> bool {
        use Property::*;
        let joins = !matches!(self, Self::StartOrControl)
            && next != Control
            && (matches!(next, Extend | Joiner | SpacingMark)
                || matches!(self, Self::Prepend)
                || (next == Pictograph && matches!(self, Self::PictographWithJoiner))
                || (next == Regional && matches!(self, Self::OddRegionalRun)));
        *self = match next {
            Control => Self::StartOrControl,
            Prepend => Self::Prepend,
            Pictograph => Self::PictographWithExtends,
            Extend if matches!(self, Self::PictographWithExtends) => Self::PictographWithExtends,
            Joiner if matches!(self, Self::PictographWithExtends) => Self::PictographWithJoiner,
            Regional if !matches!(self, Self::OddRegionalRun) => Self::OddRegionalRun,
            _ => Self::Other,
        };
        !joins
    }
}

pub(super) fn sprites(text: &str) -> impl Iterator<Item = (usize, &str, Sprite)> {
    let mut prefix = Prefix::StartOrControl;
    let mut start = None;
    // A synthetic trailing control also finishes the last possible sprite.
    text.char_indices()
        .chain(std::iter::once((text.len(), '\0')))
        .filter_map(move |(offset, ch)| {
            let kind = property(ch);
            if !prefix.boundary(kind) {
                return None;
            }
            let previous = start.take();
            if matches!(kind, Property::Pictograph | Property::Regional)
                || matches!(ch, '#' | '*' | '0'..='9' | '\u{1f3fb}'..='\u{1f3ff}')
            {
                start = Some(offset);
            }
            let from = previous?;
            let candidate: &str = &text[from..offset];
            if candidate.is_ascii() {
                return None;
            }
            sprite(candidate).map(|image| (from, candidate, image))
        })
}
