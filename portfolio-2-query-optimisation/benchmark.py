# Portfolio 2: runs 03_explain.sql several times and records the median
# execution time of each query, so one slow or fast run doesn't skew results.
#
# usage:  python benchmark.py before      (or: python benchmark.py after)
# output: evidence/timings_<label>.md

import re
import statistics
import subprocess
import sys
from pathlib import Path

RUNS = 5
label = sys.argv[1] if len(sys.argv) > 1 else "run"
here = Path(__file__).parent

cmd = ["docker", "exec", "marriott_postgres", "sh", "-c",
       "psql -U mit8103 -d marriott_crs -f /scripts/p2/03_explain.sql 2>&1"]

# one warm-up run so every measured run starts with the data in memory
subprocess.run(cmd, capture_output=True, text=True)

times = {}
for i in range(RUNS):
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    query = None
    for line in out.splitlines():
        heading = re.match(r"=== (Q\w+) ", line)
        if heading:
            query = heading.group(1)
        found = re.search(r"Execution Time: ([\d.]+) ms", line)
        if found and query:
            times.setdefault(query, []).append(float(found.group(1)))
    print(f"run {i + 1} of {RUNS} done")

lines = [f"# Query timings: {label} ({RUNS} runs, median)", "",
         "| Query | Median (ms) | Fastest (ms) | Slowest (ms) |", "|---|---|---|---|"]
for q, t in times.items():
    lines.append(f"| {q} | {statistics.median(t):.1f} | {min(t):.1f} | {max(t):.1f} |")

(here / "evidence" / f"timings_{label}.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("\n".join(lines))
