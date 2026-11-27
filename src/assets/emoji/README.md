# Emoji artwork and sequence data

Drill uses Twemoji artwork by Twitter, Jason Sofonia, Justine De Caires and other Twemoji contributors under Creative Commons Attribution 4.0 International. The pack contains the original 72 × 72 PNG files concatenated without image modifications. [Twemoji v17.0.3](https://github.com/jdecked/twemoji/tree/b6b55fef1e8636b540a6d016a4729ca8cdf2e60b) · [Graphics license](LICENSE-TWEMOJI)

The sequence index is derived from Unicode Emoji 17.0 test data, © 2025 Unicode, Inc., under the Unicode License v3. [Unicode source](https://github.com/unicode-org/unicodetools/blob/48afe632bf194a20bcd27c3488b49dc23274b684/unicodetools/data/emoji/17.0/emoji-test.txt) · [Unicode license](LICENSE-UNICODE)

## Format

Each UTF-8 line in `index.tsv` contains an exact sequence, a decimal byte offset into `twemoji.bin`, and a decimal byte length, separated by tabs. Keys are sorted by UTF-8 bytes. The 5,018 keys cover 3,944 fully qualified emoji, nine components, 1,029 minimally qualified spellings and 36 other compound spellings. Alternative spellings refer to the same PNG. Bare default-text symbols and explicit text variants use ordinary text rendering.

## Regeneration

From the Drill repository root, pass the pinned Twemoji checkout and Unicode data file to the generator. It uses the Python standard library and local inputs. The hashes cover the complete Unicode source and packed artwork.

```sh
python3 scripts/update-emoji-assets.py /path/to/twemoji /path/to/emoji-test.txt
```

| File | SHA-256 |
| --- | --- |
| Unicode 17.0 `emoji-test.txt` | `1d8a944f88d7952f7ef7c5167fef3c67995bcae24543949710231b03a201acda` |
| `twemoji.bin` | `47384454e4f90958e9e686c8c25d409c3241ce0e4160d42045efd79cbed122b6` |
| `index.tsv` | `6132c2878d306ffa10dec8adbe4257de07b2f2927054fa987c1128afee8b4fcd` |

## Sprite boundaries

Drill paints an image only when the entire emoji sequence matches an index key. The scanner
uses the grapheme and pictograph properties that can join characters to these specific
keys. Ordinary text stays in a single shaped run between images.

To regenerate `sprite-boundaries.bin`, place the Unicode 17.0.0
[GraphemeBreakProperty.txt](https://www.unicode.org/Public/17.0.0/ucd/auxiliary/GraphemeBreakProperty.txt)
and [emoji-data.txt](https://www.unicode.org/Public/17.0.0/ucd/emoji/emoji-data.txt)
in one directory and run `python3 scripts/update-emoji-boundaries.py /path/to/ucd`.
The generator verifies both source checksums. [Unicode license](LICENSE-UNICODE)
