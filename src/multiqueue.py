

import multiprocessing
import queue

class MultiQueue:
    """The idea is to have 3 different multiprocessing queues for priorities"""
    def __init__(self):
        self.high = multiprocessing.Queue()
        self.medium = multiprocessing.Queue()
        self.low = multiprocessing.Queue()
        self.cleared = False

    def put(self, item, priority='medium'):
        """Put an item into the queue with a specified priority."""
        if priority == 'high':
            self.high.put(item)
        elif priority == 'medium':
            self.medium.put(item)
        elif priority == 'low':
            self.low.put(item)
        else:
            raise ValueError("Priority must be 'high', 'medium', or 'low'")

    def get(self, timeout=None):
        """Get an item from the queue with a timeout."""
        try:
            return self.high.get_nowait()
        except queue.Empty:
            pass
        try:
            return self.medium.get_nowait()
        except queue.Empty:
            pass
        try:
            return self.low.get(timeout=timeout)
        except queue.Empty:
            pass
        raise queue.Empty("No items in any queue")
    
    def close(self):
        self.high.close()
        self.medium.close()
        self.low.close()