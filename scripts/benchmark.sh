#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -n "${PYTHON_BIN:-}" ]]; then
  PYTHON="$PYTHON_BIN"
elif [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
  PYTHON="$ROOT_DIR/.venv/bin/python"
else
  PYTHON="python3"
fi

TRACE_SECONDS="${TRACE_SECONDS:-3}"
BENCH_SECONDS="${BENCH_SECONDS:-10}"
TRACE_DIR="${TRACE_DIR:-build/traces}"

mkdir -p "$TRACE_DIR"

echo "[benchmark] Root: $ROOT_DIR"
echo "[benchmark] Python: $($PYTHON --version)"
echo "[benchmark] Search query: ."
echo "[benchmark] Runtime: ${BENCH_SECONDS}s"
echo "[benchmark] Stack dump interval: ${TRACE_SECONDS}s"
echo "[benchmark] Trace dir: $TRACE_DIR"

trace_prefix="$("$PYTHON" - <<'PY'
import datetime
print(datetime.datetime.now().strftime("%Y%m%d-%H%M%S") + ".query")
PY
)"

stack_log="$TRACE_DIR/${trace_prefix}.stacks.log"
pstats_path="$TRACE_DIR/${trace_prefix}.pstats"
summary_path="$TRACE_DIR/${trace_prefix}.txt"

"$PYTHON" - <<PY
import cProfile
import faulthandler
import io
import pstats
import sys
import time

sys.path.insert(0, "src")
from search import Search

stack_log_path = "$stack_log"
pstats_path = "$pstats_path"
summary_path = "$summary_path"
trace_seconds = float("$TRACE_SECONDS")
bench_seconds = float("$BENCH_SECONDS")

profiler = cProfile.Profile()
s = Search(".")

with open(stack_log_path, "w", encoding="utf-8") as stack_log:
    stack_log.write(f"External Drill trace\\nquery=.\\ninterval_seconds={trace_seconds}\\n\\n")
    stack_log.flush()
    faulthandler.dump_traceback_later(trace_seconds, repeat=True, file=stack_log)
    profiler.enable()
    try:
        s.start()
        end = time.monotonic() + bench_seconds
        while time.monotonic() < end:
            time.sleep(0.1)
    finally:
        profiler.disable()
        s.stop()
        faulthandler.cancel_dump_traceback_later()

profiler.dump_stats(pstats_path)
stream = io.StringIO()
stats = pstats.Stats(profiler, stream=stream).strip_dirs().sort_stats("cumulative")
stats.print_stats(120)
stats.print_callers(40)
stats.print_callees(40)
with open(summary_path, "w", encoding="utf-8") as f:
    f.write(stream.getvalue())
PY

echo "[benchmark] Stack trace log: $stack_log"
echo "[benchmark] cProfile stats: $pstats_path"
echo "[benchmark] Summary text: $summary_path"

if command -v gprof2dot >/dev/null 2>&1 && command -v dot >/dev/null 2>&1; then
  callgraph_path="${pstats_path%.pstats}.callgraph.svg"
  gprof2dot -f pstats "$pstats_path" | dot -Tsvg -o "$callgraph_path"
  echo "[benchmark] Callgraph: $callgraph_path"
else
  echo "[benchmark] Skipping callgraph render (requires: gprof2dot and graphviz 'dot')."
  echo "[benchmark] Install example: pip install gprof2dot && brew install graphviz"
fi

echo "[benchmark] Done"
