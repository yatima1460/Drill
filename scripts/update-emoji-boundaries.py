"""Pack the Unicode properties needed to recognize complete Twemoji sprites."""
import argparse
import hashlib
from pathlib import Path
import struct


OUTPUT = Path(__file__).resolve().parents[1] / "src/assets/emoji/sprite-boundaries.bin"
# The low three bits select an entry in the Rust classifier.
PROPERTIES = {"CR": 1, "LF": 1, "Control": 1, "Extend": 2, "ZWJ": 3,
              "Regional_Indicator": 4, "Prepend": 5, "SpacingMark": 6,
              "Extended_Pictographic": 7}
SOURCES = {
    "GraphemeBreakProperty.txt": "d6b51d1d2ae5c33b451b7ed994b48f1f4dc62b2272a5831e7fd418514a6bae89",
    "emoji-data.txt": "2cb2bb9455cda83e8481541ecf5b6dfda66a3bb89efa3fa7c5297eccf607b72b",
}


def pack(source_dir):
    properties = bytearray(0x110000)
    for filename, expected in SOURCES.items():
        data = (source_dir / filename).read_bytes()
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError(f"expected Unicode 17.0.0 {filename}")
        for line in data.decode().splitlines():
            entry = line.partition("#")[0].strip()
            if not entry:
                continue
            interval, name = map(str.strip, entry.split(";"))
            if name not in PROPERTIES:
                continue
            low, _, high = interval.partition("..")
            start, end = int(low, 16), int(high or low, 16) + 1
            if any(properties[start:end]):
                raise ValueError(f"overlapping sprite boundary classes at {interval}")
            properties[start:end] = bytes([PROPERTIES[name]]) * (end - start)

    return b"".join(struct.pack("<I", (point << 3) | prop)
                    for point, prop in enumerate(properties)
                    if point == 0 or prop != properties[point - 1])


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ucd_directory", type=Path)
    OUTPUT.write_bytes(pack(parser.parse_args().ucd_directory))
