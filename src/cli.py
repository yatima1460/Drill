#!/usr/bin/env python3
import sys
from typing import List
from search import Search
import os
import signal

class CLI:

    def interrupt_handler(self, signum, frame):
        self.search.stop()
        # Perform cleanup
        sys.exit(0)

    def main(self):
        if len(sys.argv) < 2:
            print("Error: Please provide a search query as an argument.")
            print("Usage: python cli.py <search_query>")
            sys.exit(1)
        
        query = sys.argv[1]
        
        self.search = Search(query)
        
        #results = self.search.start()
        
        # Print the results
        print(f"Search results for: '{query}'")
        print("-" * 40)
        while self.search.is_running():
            try:
                result = self.search.pop_result(block=True)
                if result:
                    print(os.path.join(result[1], result[0]))
                else:
                    print("No more results.")
            except BaseException as e:
                print(f"Error processing result: {e}")
                break

if __name__ == "__main__":
    cli = CLI()
    signal.signal(signal.SIGINT, cli.interrupt_handler)
    cli.main()
    