#!/usr/bin/env python3
import sys
from search import Search
import os
import signal
import time
from typing import Any

class CLI:
    def __init__(self):
        self.search: Any = None

    def interrupt_handler(self, signum, frame):
        if hasattr(self, "search") and self.search is not None:
            self.search.stop()
        # Perform cleanup
        sys.exit(0)

    def _is_running(self):
        is_running = getattr(self.search, "is_running", None)
        if callable(is_running):
            return bool(is_running())
        is_done = getattr(self.search, "is_done", None)
        if callable(is_done):
            return not bool(is_done())
        return False

    def _pop_result(self):
        pop_result = getattr(self.search, "pop_result", None)
        if not callable(pop_result):
            return None
        try:
            return pop_result(block=True)
        except TypeError:
            return pop_result()

    def _format_result(self, result):
        if hasattr(result, "path"):
            return result.path
        if isinstance(result, (list, tuple)) and len(result) >= 2:
            return os.path.join(result[1], result[0])
        return str(result)

    def main(self):
        if len(sys.argv) < 2:
            print("Error: Please provide a search query as an argument.")
            print("Usage: python cli.py <search_query>")
            sys.exit(1)

        query = sys.argv[1]
        expected = os.environ.get("DRILL_EXPECT_RESULT_CONTAINS", "").strip().lower()
        max_seconds_raw = os.environ.get("DRILL_CLI_MAX_SECONDS", "").strip()
        max_seconds = float(max_seconds_raw) if max_seconds_raw else 0.0
        start_time = time.monotonic()
        found_expected = expected == ""

        self.search = Search(query)
        if hasattr(self.search, "start"):
            self.search.start()

        # Print the results
        print(f"Search results for: '{query}'")
        print("-" * 40)
        while self._is_running():
            try:
                result = self._pop_result()
                if result:
                    formatted = self._format_result(result)
                    print(formatted)
                    if expected and expected in formatted.lower():
                        found_expected = True
                elif hasattr(self.search, "is_done") and self.search.is_done():
                    print("No more results.")
                    break
                else:
                    time.sleep(0.05)
                if max_seconds > 0 and (time.monotonic() - start_time) > max_seconds:
                    print(f"Timeout after {max_seconds:.1f}s waiting for expected result.")
                    if hasattr(self, "search") and self.search is not None:
                        self.search.stop()
                    break
            except BaseException as e:
                print(f"Error processing result: {e}")
                break

        if expected and not found_expected:
            print(f"Expected result containing '{expected}' not found.")
            return 2
        return 0

if __name__ == "__main__":
    cli = CLI()
    signal.signal(signal.SIGINT, cli.interrupt_handler)
    sys.exit(cli.main())
    
