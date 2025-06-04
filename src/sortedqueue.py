import queue
import functools
from os import DirEntry

from drillentry import DrillEntry

class SortedQueue:
    def __init__(self):
        self._queue = []

    # Internal comparator: change this logic to suit your needs
    def _comparator(self, a: DrillEntry, b: DrillEntry) -> int:
        
        # Not hidden files should come first
        a_name = a.name
        b_name = b.name
        if a_name[0] == "." and b_name[0] != ".":
            return 1
        elif a_name[0] != "." and b_name[0] == ".":
            return -1
    
        # # Most recently modified files should come first
        if a.modified_time < b.modified_time:
            return 1
        elif a.modified_time > b.modified_time:
            return -1
        
        # Less importance to folders deep in the hierarchy
        a_slashes = a.path.count("/")
        b_slashes = b.path.count("/")
        delta = b_slashes - a_slashes
        if delta != 0:
            return delta

        return 0
        

    def put(self, item: DrillEntry):
        self._queue.append(item)
        # Use the internal comparator for sorting
        self._queue.sort(key=functools.cmp_to_key(self._comparator))
        
    def get(self) -> DrillEntry:
        if not self._queue:
            raise queue.Empty("Queue is empty")
        return self._queue.pop(0)
    
    def qsize(self) -> int:
        return len(self._queue)