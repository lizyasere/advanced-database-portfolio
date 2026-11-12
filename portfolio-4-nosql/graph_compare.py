# Portfolio 4: time two graph questions in PostgreSQL (SQL joins) and Neo4j (Cypher).
# Each query runs once to warm up, then 5 timed runs; the table shows the median.
#
# usage:  python graph_compare.py
# output: evidence/graph_compare.md

import re
import statistics
import subprocess
from pathlib import Path

HERE = Path(__file__).parent
CYPHER = (HERE / "07_graph_queries.cypher").read_text().split(";")
QUESTIONS = {"also_stayed": ("Guests who stayed at LOSMC also stayed at", CYPHER[0]),
             "recommend": ("Hotel recommendations for one guest", CYPHER[2])}


def pg_ms(name):
    out = subprocess.run(["docker", "exec", "marriott_postgres", "psql", "-U", "mit8103", "-d", "marriott_crs",
                          "-f", f"/scripts/p4/compare/pg_{name}.sql"],
                         capture_output=True, text=True).stdout
    return float(re.findall(r"Time: ([\d.]+) ms", out)[-1])


def neo_ms(query):
    out = subprocess.run(["docker", "exec", "marriott_neo4j", "cypher-shell", "-u", "neo4j", "-p", "mit8103_pass",
                          "--format", "verbose", query], capture_output=True, text=True).stdout
    a, b = re.search(r"after (\d+) ms, results consumed after another (\d+) ms", out).groups()
    return int(a) + int(b)


rows = ["| Question | PostgreSQL (ms) | Neo4j (ms) |", "|---|---|---|"]
for name, (label, cypher) in QUESTIONS.items():
    pg_ms(name); neo_ms(cypher)                       # warm up
    pg = statistics.median(pg_ms(name) for _ in range(5))
    neo = statistics.median(neo_ms(cypher) for _ in range(5))
    rows.append(f"| {label} | {pg:.0f} | {neo:.0f} |")
text = "Median of 5 runs after one warm-up run\n\n" + "\n".join(rows) + "\n"
print(text)
(HERE / "evidence" / "graph_compare.md").write_text(text, encoding="utf-8")
