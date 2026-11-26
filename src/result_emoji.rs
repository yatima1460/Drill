use eframe::egui::{self, Color32, FontId, Painter, Pos2, Rect, TextureHandle, TextureId};
use std::{collections::VecDeque, sync::OnceLock};
use unicode_segmentation::UnicodeSegmentation;

const PACK: &[u8] = include_bytes!("assets/emoji/twemoji.bin");
const MAX_TEXTURES: usize = 256;

#[derive(Clone, Copy)]
struct Sprite {
    offset: usize,
    len: usize,
}

fn sprite(cluster: &str) -> Option<Sprite> {
    static INDEX: OnceLock<Vec<(&str, Sprite)>> = OnceLock::new();
    let index = INDEX.get_or_init(|| {
        include_str!("assets/emoji/index.tsv")
            .lines()
            .map(|line| {
                let mut fields = line.split('\t');
                let key = fields.next().unwrap();
                let offset = fields.next().unwrap().parse().unwrap();
                let len = fields.next().unwrap().parse().unwrap();
                (key, Sprite { offset, len })
            })
            .collect()
    });
    let i = index.binary_search_by_key(&cluster, |(key, _)| *key).ok()?;
    Some(index[i].1)
}

#[derive(Default)]
pub(super) struct EmojiCache(VecDeque<(usize, TextureHandle)>);

impl EmojiCache {
    fn texture(&mut self, painter: &Painter, sprite: Sprite) -> TextureId {
        if let Some((_, texture)) = self.0.iter().find(|(offset, _)| *offset == sprite.offset) {
            return texture.id();
        }
        let png = &PACK[sprite.offset..sprite.offset + sprite.len];
        let rgba = image::load_from_memory_with_format(png, image::ImageFormat::Png)
            .expect("invalid bundled emoji PNG")
            .into_rgba8();
        let pixels = egui::ColorImage::from_rgba_unmultiplied(
            [rgba.width() as usize, rgba.height() as usize],
            rgba.as_raw(),
        );
        let texture =
            painter
                .ctx()
                .load_texture("result emoji", pixels, egui::TextureOptions::LINEAR);
        let id = texture.id();
        if self.0.len() == MAX_TEXTURES {
            self.0.pop_front();
        }
        self.0.push_back((sprite.offset, texture));
        id
    }

    pub(super) fn paint(
        &mut self,
        painter: &Painter,
        mut pos: Pos2,
        text: &str,
        font: FontId,
        color: Color32,
    ) {
        let plain =
            |pos, run: &str| painter.text(pos, egui::Align2::LEFT_CENTER, run, font.clone(), color);
        // Most rows need a single normal galley. Keep kerning and shaping for contiguous text.
        let mut start = 0;
        if !text.is_ascii() {
            for (offset, cluster) in text.grapheme_indices(true) {
                if cluster.is_ascii() {
                    continue;
                }
                let Some(sprite) = sprite(cluster) else {
                    continue;
                };
                if start < offset {
                    pos.x = plain(pos, &text[start..offset]).right();
                }
                if pos.x >= painter.clip_rect().right() {
                    return;
                }
                let rect = Rect::from_min_size(
                    pos - egui::vec2(0.0, font.size * 0.5),
                    egui::Vec2::splat(font.size),
                );
                if rect.intersects(painter.clip_rect()) {
                    let id = self.texture(painter, sprite);
                    painter.image(
                        id,
                        rect,
                        Rect::from_min_max(Pos2::ZERO, egui::pos2(1.0, 1.0)),
                        Color32::WHITE,
                    );
                }
                pos.x = rect.right();
                start = offset + cluster.len();
            }
        }
        if start < text.len() && pos.x < painter.clip_rect().right() {
            plain(pos, &text[start..]);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn emoji_lookup_preserves_text_presentation_and_matches_complete_sequences() {
        for text in ["1", "©", "™", "❤", "❤︎", "e\u{301}"] {
            assert!(sprite(text).is_none(), "{text}");
        }
        for emoji in ["😭", "🥀", "🇸🇮", "👩🏽‍💻", "1️⃣", "❤️"] {
            assert_eq!(emoji.graphemes(true).count(), 1);
            let entry = sprite(emoji).unwrap();
            assert!(PACK[entry.offset..entry.offset + entry.len].starts_with(b"\x89PNG"));
        }
    }
}
