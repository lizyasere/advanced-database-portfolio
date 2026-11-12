# Portfolio 4: time the same three screens in PostgreSQL and MongoDB.
# PostgreSQL is timed with pgbench and MongoDB with a loop in mongosh, both inside their
# own containers, so the network is the same for both.
#
# usage:  python compare.py
# output: evidence/compare.md

import re
import subprocess
from pathlib import Path

HERE = Path(__file__).parent
RUNS = {"baseline": 500, "profile": 500, "booking": 500, "brand_nights": 5}
LABELS = {"baseline": "Empty query (SELECT 1 / ping): client and round trip only",
          "profile": "Guest profile screen (profile, Bonvoy, 3 recent bookings)",
          "booking": "Booking detail screen (booking, guest, hotel, room, payments, points)",
          "brand_nights": "Room nights by brand, last 12 months (analytics)"}


def pg(name):
    out = subprocess.run(["docker", "exec", "marriott_postgres", "pgbench", "-U", "mit8103", "-n",
                          "-t", str(RUNS[name]), "-f", f"/scripts/p4/compare/pg_{name}.sql", "marriott_crs"],
                         capture_output=True, text=True).stdout
    return float(re.search(r"latency average = ([\d.]+) ms", out).group(1))


mongo_out = subprocess.run(["docker", "exec", "marriott_mongo", "mongosh", "--quiet",
                            "/scripts/p4/compare/mongo_bench.js"], capture_output=True, text=True).stdout
mongo = {line.split()[0]: float(line.split()[1]) for line in mongo_out.strip().splitlines()}

def psql(sql):
    subprocess.run(["docker", "exec", "marriott_postgres", "psql", "-U", "mit8103", "-d", "marriott_crs",
                    "-q", "-c", sql], capture_output=True)


before = {name: pg(name) for name in RUNS}
# the booking screen joins points_transaction on reservation_id, which has no index yet
psql("CREATE INDEX idx_points_reservation ON crs.points_transaction (reservation_id); ANALYZE crs.points_transaction;")
after = {name: pg(name) for name in RUNS}
psql("DROP INDEX crs.idx_points_reservation;")

rows = ["| Screen | PostgreSQL (ms) | PostgreSQL + index on points.reservation_id (ms) | MongoDB (ms) |",
        "|---|---|---|---|"]
for name in RUNS:
    rows.append(f"| {LABELS[name]} | {before[name]:.3f} | {after[name]:.3f} | {mongo[name]:.3f} |")
text = "Average time per query (" + ", ".join(f"{n}: {r} runs" for n, r in RUNS.items()) + ")\n\n" + "\n".join(rows) + "\n"
print(text)
(HERE / "evidence" / "compare.md").write_text(text, encoding="utf-8")
