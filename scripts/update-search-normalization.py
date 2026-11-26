"""Generate Drill's search-folding tables from the official Unicode 18 UCD."""
import argparse
from functools import lru_cache
import hashlib
from pathlib import Path
import struct


OUTPUT = Path(__file__).resolve().parents[1] / "crates/drill-query/src/normalization"
UCD_SHA256 = "0736451de439ae7baf1425136617da495e09ee5afbe6e394374db7009ea08950"


def mappings(data):
    marks = set()
    decompositions = {}
    for line in data.decode("utf-8").splitlines():
        code, name, category, ccc, _, decomposition, *_ = line.split(";")
        point = int(code, 16)
        # Every scalar moved by canonical ordering disappears in our projection.
        if ccc != "0" and not category.startswith("M"):
            raise ValueError(f"non-mark with a nonzero combining class: {code}")
        if name.endswith(", First>") or name.endswith(", Last>"):
            # UCD ranges describe identity mappings here. Hangul is algorithmic.
            if category.startswith("M") or decomposition:
                raise ValueError(f"unhandled UCD range: {name}")
        if category.startswith("M"):
            marks.add(point)
        if decomposition and not decomposition.startswith("<"):
            decompositions[point] = tuple(int(c, 16) for c in decomposition.split())

    @lru_cache(None)
    def project(point):
        if point in decompositions:
            return "".join(project(child) for child in decompositions[point])
        return "" if point in marks else chr(point)

    return [(c, project(c)) for c in sorted(marks | decompositions.keys()) if project(c) != chr(c)]


def generate(source):
    data = source.read_bytes()
    if hashlib.sha256(data).hexdigest() != UCD_SHA256:
        raise ValueError("expected Unicode 18.0.0 UnicodeData.txt")
    # Combine consecutive scalars with identical replacements, especially marks.
    spans = []
    for point, text in mappings(data):
        if spans and spans[-1][1] + 1 == point and spans[-1][2] == text:
            first = spans[-1][0]
            spans[-1] = (first, point, text)
        else:
            spans.append((point, point, text))

    ranges = bytearray()
    replacements = bytearray()
    offsets = {}
    for first, last, text in spans:
        value = text.encode("utf-8")
        if value not in offsets:
            offsets[value] = len(replacements)
            replacements.extend(value)
        ranges.extend(struct.pack("<IIHH", first, last, offsets[value], len(value)))
    (OUTPUT / "ranges.bin").write_bytes(ranges)
    (OUTPUT / "replacements.bin").write_bytes(replacements)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("unicode_data", type=Path)
    generate(parser.parse_args().unicode_data)
