#!/usr/bin/env python3
"""Forward rustc's final link to the selected C compiler driver and time it."""
import os
import subprocess
import sys
import time

start = time.perf_counter()
result = subprocess.run([os.environ["DRILL_BENCH_LINKER"], *sys.argv[1:]])
elapsed = time.perf_counter() - start
if result.returncode == 0 and "-o" in sys.argv[1:]:
    with open(os.environ["DRILL_BENCH_LINK_LOG"], "a") as log:
        print(elapsed, file=log)
sys.exit(result.returncode if result.returncode >= 0 else 128 - result.returncode)
