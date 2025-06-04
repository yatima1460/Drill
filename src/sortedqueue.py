import queue
import functools
from os import DirEntry

from drillentry import DrillEntry

class SortedQueue:
    def __init__(self):
        self._queue = []

    def put(self, item: DrillEntry):
        self._queue.append(item)
        # Use the internal comparator for sorting
        self._queue.sort()
        
    def get(self) -> DrillEntry:
        if not self._queue:
            raise queue.Empty("Queue is empty")
        return self._queue.pop(0)
    
    def qsize(self) -> int:
        return len(self._queue)