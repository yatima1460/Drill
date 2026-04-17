import importlib.util
import os
import random
import sys

import pytest

src_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src"))
sys.path.insert(0, src_path)

from sortedset import SortedSet


def _ref_pop_min(values: set[int]) -> int:
    v = min(values)
    values.remove(v)
    return v


def _ref_pop_max(values: set[int]) -> int:
    v = max(values)
    values.remove(v)
    return v


def test_sortedset_randomized_int_operations():
    for seed in range(16):
        rng = random.Random(seed)
        s = SortedSet()
        ref: set[int] = set()

        for _ in range(600):
            op = rng.choices(
                ["add", "pop0", "pop_last", "discard", "remove", "clear"],
                weights=[50, 16, 8, 12, 8, 6],
                k=1,
            )[0]
            value = rng.randint(-200, 200)

            if op == "add":
                s.add(value)
                ref.add(value)
            elif op == "pop0":
                if ref:
                    assert s.pop(0) == _ref_pop_min(ref)
                else:
                    with pytest.raises(IndexError):
                        s.pop(0)
            elif op == "pop_last":
                if ref:
                    assert s.pop(-1) == _ref_pop_max(ref)
                else:
                    with pytest.raises(IndexError):
                        s.pop(-1)
            elif op == "discard":
                s.discard(value)
                ref.discard(value)
            elif op == "remove":
                if value in ref:
                    s.remove(value)
                    ref.remove(value)
                else:
                    with pytest.raises(KeyError):
                        s.remove(value)
            else:
                s.clear()
                ref.clear()

            assert len(s) == len(ref)
            assert bool(s) == bool(ref)
            assert list(s) == sorted(ref)
            assert (value in s) == (value in ref)


class Box:
    __slots__ = ("key",)

    def __init__(self, key: int):
        self.key = key

    def __lt__(self, other):
        return self.key < other.key

    def __eq__(self, other):
        return isinstance(other, Box) and self.key == other.key

    def __hash__(self):
        return hash(self.key)

    def __repr__(self):
        return f"Box({self.key})"


def test_sortedset_custom_comparable_generated_data():
    rng = random.Random(20260417)
    s = SortedSet()
    data = [Box(rng.randint(-500, 500)) for _ in range(2000)]
    for item in data:
        s.add(item)

    keys = [item.key for item in s]
    assert keys == sorted(set(keys))

    popped = []
    while s:
        popped.append(s.pop(0).key)
    assert popped == sorted(set(popped))


@pytest.mark.skipif(
    importlib.util.find_spec("sortedcontainers") is None,
    reason="sortedcontainers not installed in this environment",
)
def test_sortedset_behavior_matches_sortedcontainers_on_generated_ops():
    from sortedcontainers import SortedSet as LibSortedSet

    rng = random.Random(4242)
    local = SortedSet()
    lib = LibSortedSet()

    for _ in range(1200):
        op = rng.choices(
            ["add", "pop0", "pop_last", "discard", "remove", "clear"],
            weights=[48, 16, 8, 12, 10, 6],
            k=1,
        )[0]
        value = rng.randint(-400, 400)

        if op == "add":
            local.add(value)
            lib.add(value)
        elif op == "pop0":
            if lib:
                assert local.pop(0) == lib.pop(0)
            else:
                with pytest.raises(IndexError):
                    local.pop(0)
        elif op == "pop_last":
            if lib:
                assert local.pop(-1) == lib.pop(-1)
            else:
                with pytest.raises(IndexError):
                    local.pop(-1)
        elif op == "discard":
            local.discard(value)
            lib.discard(value)
        elif op == "remove":
            if value in lib:
                local.remove(value)
                lib.remove(value)
            else:
                with pytest.raises(KeyError):
                    local.remove(value)
        else:
            local.clear()
            lib.clear()

        assert list(local) == list(lib)
        assert len(local) == len(lib)
