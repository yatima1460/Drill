"""Pack Twemoji's original PNGs for the emoji sequences in Unicode emoji-test.txt."""
import argparse
import hashlib
from pathlib import Path
import struct


OUTPUT = Path(__file__).resolve().parents[1] / "src" / "assets" / "emoji"
UNICODE_SHA256 = "1d8a944f88d7952f7ef7c5167fef3c67995bcae24543949710231b03a201acda"
PACK_SHA256 = "47384454e4f90958e9e686c8c25d409c3241ce0e4160d42045efd79cbed122b6"


def sequences(emoji_test):
    data = emoji_test.read_bytes()
    if hashlib.sha256(data).hexdigest() != UNICODE_SHA256:
        raise ValueError("expected the pinned Unicode 17.0 emoji-test.txt")
    for line in data.decode("utf-8").splitlines():
        record = line.partition("#")[0].strip()
        if record:
            points, status = record.split(";")
            sequence = "".join(chr(int(p, 16)) for p in points.split())
            # ©, ™, ❤ and other unqualified singletons have text presentation.
            if status.strip() == "unqualified" and len(sequence) == 1:
                continue
            yield sequence


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("twemoji", type=Path, help="local Twemoji v17.0.3 checkout")
    parser.add_argument("emoji_test", type=Path, help="local Unicode 17.0 emoji-test.txt")
    args = parser.parse_args()

    sprites = {}
    for path in (args.twemoji / "assets" / "72x72").glob("*.png"):
        key = "".join(chr(int(p, 16)) for p in path.stem.split("-")).replace("\ufe0f", "")
        if key in sprites:
            raise ValueError(f"ambiguous Twemoji artwork: {path.name}")
        sprites[key] = path

    # Only the artwork lookup ignores VS16. The stored keys retain the exact input.
    lookup = {key: sprites[key.replace("\ufe0f", "")] for key in sequences(args.emoji_test)}
    packed = bytearray()
    spans = {}
    for path in sorted(set(lookup.values())):
        png = path.read_bytes()
        if png[:16] != b"\x89PNG\r\n\x1a\n\0\0\0\rIHDR" or struct.unpack(">II", png[16:24]) != (72, 72):
            raise ValueError(f"expected a 72 × 72 PNG: {path.name}")
        spans[path] = (len(packed), len(png))
        packed.extend(png)

    if hashlib.sha256(packed).hexdigest() != PACK_SHA256:
        raise ValueError("expected the pinned Twemoji v17.0.3 artwork")

    lines = []
    for key in sorted(lookup, key=str.encode):
        offset, length = spans[lookup[key]]
        lines.append(f"{key}\t{offset}\t{length}\n")
    (OUTPUT / "twemoji.bin").write_bytes(packed)
    (OUTPUT / "index.tsv").write_bytes("".join(lines).encode("utf-8"))
    print(f"{len(spans)} PNGs, {len(lines)} sequence keys, {len(packed)} packed bytes")


if __name__ == "__main__":
    main()
