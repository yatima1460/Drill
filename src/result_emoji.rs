use eframe::egui::{self, Color32, FontId, Painter, Pos2, Rect, TextureHandle};
use std::{collections::HashMap, sync::OnceLock};
mod boundaries;
use boundaries::sprites;

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
pub(super) struct EmojiCache(HashMap<usize, (u64, TextureHandle)>);

impl EmojiCache {
    fn texture(&mut self, painter: &Painter, sprite: Sprite) -> TextureHandle {
        let pass = painter.ctx().cumulative_pass_nr();
        if let Some((last_used, texture)) = self.0.get_mut(&sprite.offset) {
            *last_used = pass;
            return texture.clone();
        }
        let png = &PACK[sprite.offset..sprite.offset + sprite.len];
        let image = eframe::icon_data::from_png_bytes(png).expect("invalid bundled emoji PNG");
        let pixels = egui::ColorImage::from_rgba_unmultiplied(
            [image.width as usize, image.height as usize],
            &image.rgba,
        );
        let texture =
            painter
                .ctx()
                .load_texture("result emoji", pixels, egui::TextureOptions::LINEAR);
        if self.0.len() == MAX_TEXTURES {
            let oldest = self.0.iter().min_by_key(|(_, (last_used, _))| last_used);
            if let Some((&key, &(last_used, _))) = oldest {
                if last_used == pass {
                    // A full viewport can exceed the cache. Draw the overflow without
                    // evicting other visible glyphs that will be reused next frame.
                    return texture;
                }
                self.0.remove(&key);
            }
        }
        self.0.insert(sprite.offset, (pass, texture.clone()));
        texture
    }

    pub(super) fn paint(
        &mut self,
        painter: &Painter,
        mut pos: Pos2,
        text: &str,
        font: FontId,
        color: Color32,
    ) {
        if text.contains('\n') && !text.is_ascii() && sprites(text).next().is_some() {
            let height = painter.fonts(|fonts| fonts.row_height(&font));
            let lines = text.split('\n');
            pos.y -= height * (lines.clone().count() - 1) as f32 / 2.0;
            for line in lines {
                self.paint_line(painter, pos, line, &font, color);
                pos.y += height;
            }
        } else {
            self.paint_line(painter, pos, text, &font, color);
        }
    }

    fn paint_line(
        &mut self,
        painter: &Painter,
        mut pos: Pos2,
        text: &str,
        font: &FontId,
        color: Color32,
    ) {
        let plain =
            |pos, run: &str| painter.text(pos, egui::Align2::LEFT_CENTER, run, font.clone(), color);
        // Most rows need a single normal galley. Keep kerning and shaping for contiguous text.
        let mut start = 0;
        if !text.is_ascii() {
            for (offset, cluster, sprite) in sprites(text) {
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
                    let texture = self.texture(painter, sprite);
                    painter.image(
                        texture.id(),
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
            assert_eq!(
                sprites(emoji).map(|(_, s, _)| s).collect::<Vec<_>>(),
                [emoji]
            );
            let entry = sprite(emoji).unwrap();
            assert!(PACK[entry.offset..entry.offset + entry.len].starts_with(b"\x89PNG"));
        }
    }

    #[test]
    fn every_index_key_is_a_complete_sprite() {
        for line in include_str!("assets/emoji/index.tsv").lines() {
            let (key, _) = line.split_once('\t').unwrap();
            let mut matches = sprites(key);
            assert_eq!(
                matches.next().map(|(offset, k, _)| (offset, k)),
                Some((0, key))
            );
            assert!(matches.next().is_none());
        }
    }

    #[test]
    fn sprites_preserve_boundaries_in_mixed_filenames() {
        let cases: &[(&str, &[&str])] = &[
            ("The fly 😭🥀.mp4", &["😭", "🥀"]),
            ("👩\u{200d}🌲 and 🌲\u{301}", &[]),
            ("🍇\u{301}\u{200d}🥀 and 🍇\u{903}\u{200d}🥀", &["🥀"]),
            ("\u{600}🌲🌲 and 🥀\u{903}", &["🌲"]),
            ("🏽.x🏽\r\n🏾", &["🏽", "🏾"]),
            ("🇸🇮🇦 and 🇦🇸🇮", &["🇸🇮", "🇦🇸"]),
            ("1️⃣.txt 1️⃣\u{301} 1︎", &["1️⃣"]),
            ("가🌲क्क🍇", &["🌲", "🍇"]),
        ];
        for &(text, expected) in cases {
            let actual: Vec<_> = sprites(text)
                .map(|(offset, key, _)| {
                    assert_eq!(&text[offset..offset + key.len()], key);
                    key
                })
                .collect();
            assert_eq!(actual, expected, "{text}");
        }
    }

    #[test]
    fn emoji_overflow_does_not_evict_the_rest_of_a_visible_page() {
        let mut sprites = Vec::new();
        let mut seen = std::collections::HashSet::new();
        for line in include_str!("assets/emoji/index.tsv").lines() {
            let entry = sprite(line.split_once('\t').unwrap().0).unwrap();
            if seen.insert(entry.offset) {
                sprites.push(entry);
            }
            if sprites.len() > MAX_TEXTURES {
                break;
            }
        }
        assert_eq!(sprites.len(), MAX_TEXTURES + 1);
        let mut cache = EmojiCache::default();
        let ctx = egui::Context::default();
        for expected_uploads in [MAX_TEXTURES + 1, 1, 1] {
            let output = ctx.run(Default::default(), |ctx| {
                for &sprite in &sprites {
                    let _ = cache.texture(&ctx.debug_painter(), sprite);
                }
            });
            assert_eq!(cache.0.len(), MAX_TEXTURES);
            assert_eq!(
                output
                    .textures_delta
                    .set
                    .iter()
                    .filter(|(_, d)| d.image.size() == [72, 72])
                    .count(),
                expected_uploads
            );
        }
    }
}
