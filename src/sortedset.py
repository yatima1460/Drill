from __future__ import annotations

import heapq
from typing import Generic, Iterable, Iterator, Protocol, TypeVar


class SupportsHeapItem(Protocol):
    def __hash__(self) -> int:
        ...

    def __lt__(self, other: object, /) -> bool:
        ...

T = TypeVar("T", bound=SupportsHeapItem)


class SortedSet(Generic[T]):
    """
    Lightweight sorted set tuned for queue-like usage:
    - unique membership checks via hash set
    - fast minimum pops via heap
    """

    def __init__(self, iterable: Iterable[T] | None = None):
        self._heap: list[T] = []
        self._members: set[T] = set()
        if iterable is not None:
            for item in iterable:
                self.add(item)

    def __bool__(self) -> bool:
        return bool(self._heap)

    def __len__(self) -> int:
        return len(self._heap)

    def __iter__(self) -> Iterator[T]:
        # Not used by the current search path; keep deterministic ordering.
        return iter(sorted(self._members))

    def __contains__(self, value: T) -> bool:
        return value in self._members

    def clear(self) -> None:
        self._heap.clear()
        self._members.clear()

    def add(self, value: T) -> None:
        if value in self._members:
            return
        self._members.add(value)

        heapq.heappush(self._heap, value)

    def pop(self, index: int = -1) -> T:
        if not self._heap:
            raise IndexError("pop from empty SortedSet")

        # Search code uses pop(0), so make that path optimal.
        if index == 0:
            value = heapq.heappop(self._heap)
            self._members.remove(value)
            return value

        # Compatibility path for pop() / pop(-1): remove current max.
        if index in (-1, len(self._heap) - 1):
            max_idx = max(range(len(self._heap)), key=lambda i: self._heap[i])
            value = self._heap[max_idx]
            last = self._heap.pop()
            if max_idx < len(self._heap):
                self._heap[max_idx] = last
                heapq.heapify(self._heap)
            self._members.remove(value)
            return value

        raise IndexError("SortedSet only supports pop(0) and pop(-1)")

    def discard(self, value: T) -> None:
        if value not in self._members:
            return
        self._members.remove(value)
        # Rebuild heap from remaining members. Slow path, unused in search.
        self._heap = list(self._members)
        heapq.heapify(self._heap)

    def remove(self, value: T) -> None:
        if value not in self:
            raise KeyError(value)
        self.discard(value)

    def __repr__(self) -> str:
        return f"SortedSet({list(self)!r})"
