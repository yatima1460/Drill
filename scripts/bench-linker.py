#!/usr/bin/env python3
"""Forward rustc's final link to the selected C compiler driver and time it."""
import os
import subprocess
import sys
import time

args = sys.argv[1:]
start = time.perf_counter()
result = subprocess.run([os.environ["DRILL_BENCH_LINKER"], *args])
elapsed = time.perf_counter() - start
# rustc may put the whole link command in a response file on large builds.
if result.returncode == 0 and ("-o" in args or any(arg.startswith("@") for arg in args)):
    with open(os.environ["DRILL_BENCH_LINK_LOG"], "a") as log:
        print(elapsed, file=log)
sys.exit(result.returncode if result.returncode >= 0 else 128 - result.returncode)
