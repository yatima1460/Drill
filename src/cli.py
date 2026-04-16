#!/usr/bin/env python3
import sys
from search import Search
import os
import signal
import time

class CLI:

    def interrupt_handler(self, signum, frame):
        if hasattr(self, "search") and self.search is not None:
            self.search.stop()
        # Perform cleanup
        sys.exit(0)

    def _is_running(self):
        if hasattr(self.search, "is_running"):
            return self.search.is_running()
        if hasattr(self.search, "is_done"):
            return not self.search.is_done()
        return False

    def _pop_result(self):
        pop_result = self.search.pop_result
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
                    print(self._format_result(result))
                elif hasattr(self.search, "is_done") and self.search.is_done():
                    print("No more results.")
                    break
                else:
                    time.sleep(0.05)
            except BaseException as e:
                print(f"Error processing result: {e}")
                break

if __name__ == "__main__":
    cli = CLI()
    signal.signal(signal.SIGINT, cli.interrupt_handler)
    cli.main()
    
