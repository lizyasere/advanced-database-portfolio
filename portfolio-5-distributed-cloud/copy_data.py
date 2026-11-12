# Portfolio 5: copy the Marriott data from the Portfolio 4 MongoDB into the replica set.
# Only upcoming bookings (check-in from 12 Nov 2026) are copied: the live booking data that
# a reservation system has to keep available. mongodump output is streamed straight into
# mongorestore, so nothing is written to disk.
#
# usage:  python copy_data.py
# output: evidence/copy_data.txt

import subprocess
from pathlib import Path

HERE = Path(__file__).parent
TARGET = "mongodb://rs1:27017,rs2:27017,rs3:27017/?replicaSet=rs0"
COLLECTIONS = {"hotels": None, "guests": None, "availability": None,
               "reservations": '{"check_in": {"$gte": {"$date": "2026-11-12T00:00:00Z"}}}'}
lines = []

for name, query in COLLECTIONS.items():
    dump = ["docker", "exec", "marriott_mongo", "mongodump", "--quiet", "--archive",
            "--db", "marriott", "--collection", name]
    if query:
        dump += ["--query", query]
    export = subprocess.Popen(dump, stdout=subprocess.PIPE)
    restore = subprocess.run(["docker", "exec", "-i", "p5_rs1", "mongorestore", "--quiet", "--archive",
                              "--drop", "--uri", TARGET], stdin=export.stdout, capture_output=True, text=True)
    export.wait()
    if restore.returncode != 0:
        raise SystemExit(restore.stderr)

check = subprocess.run(["docker", "exec", "p5_rs1", "mongosh", "--quiet", TARGET, "--eval",
                        'db = db.getSiblingDB("marriott"); '
                        '["hotels", "guests", "availability", "reservations"].forEach(c => '
                        'print(c.padEnd(13) + String(db[c].countDocuments()).padStart(8)))'],
                       capture_output=True, text=True)
lines.append("Copied to the replica set rs0:")
lines.append(check.stdout.rstrip())
print("\n".join(lines))
(HERE / "evidence" / "copy_data.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
