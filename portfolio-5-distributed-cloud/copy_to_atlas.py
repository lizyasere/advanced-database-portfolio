# Portfolio 5: copy the Marriott data from the local cluster to MongoDB Atlas (free M0 tier).
# Source is whichever local P5 profile is running: mongos (sharded) or rs1 (replica set).
# The Atlas connection string stays in atlas-credentials.env (git ignored). It is read inside
# a throwaway container, so it never appears in the output or on the command line.
#
# usage:  python copy_to_atlas.py [collection ...]     (default: all four)
# output: evidence/copy_to_atlas.txt (appended per run)

import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).parent.resolve()
CREDS = HERE / "atlas-credentials.env"
SOURCES = {"p5_mongos": "mongodb://localhost:27017",
           "p5_rs1": "mongodb://rs1:27017,rs2:27017,rs3:27017/?replicaSet=rs0"}
UPCOMING = '{"check_in": {"$gte": {"$date": "2026-11-12T00:00:00Z"}}}'


def running(name):
    out = subprocess.run(["docker", "ps", "-q", "-f", f"name=^{name}$"], capture_output=True, text=True)
    return bool(out.stdout.strip())


def atlas(shell_cmd, stdin=None):
    # Runs a command in a mongo container with MONGODB_URI loaded from the credentials file.
    cmd = ["docker", "run", "--rm", "-i",
           "--mount", f"type=bind,src={CREDS},dst=/run/atlas.env,readonly",
           "mongo:7.0.14", "sh", "-c", f'set -a; . /run/atlas.env; set +a; {shell_cmd}']
    return subprocess.run(cmd, stdin=stdin, capture_output=True, text=True)


source = next((c for c in SOURCES if running(c)), None)
if not source:
    raise SystemExit("Start a P5 profile first (replica or sharded).")
wanted = sys.argv[1:] or ["hotels", "guests", "availability", "reservations"]
lines = [f"Source: {source}"]

for name in wanted:
    dump = ["docker", "exec", source, "mongodump", "--quiet", "--archive", "--uri", SOURCES[source],
            "--db", "marriott", "--collection", name]
    if name == "reservations":
        dump += ["--query", UPCOMING]
    start = time.perf_counter()
    export = subprocess.Popen(dump, stdout=subprocess.PIPE)
    restore = atlas('mongorestore --quiet --archive --drop --uri "$MONGODB_URI"', stdin=export.stdout)
    export.wait()
    if restore.returncode != 0:
        raise SystemExit(restore.stderr.replace("\n", " ")[-400:])
    lines.append(f"  {name:<13} copied in {time.perf_counter() - start:6.1f} s")

check = atlas('mongosh "$MONGODB_URI" --quiet --eval \'db = db.getSiblingDB("marriott"); '
              'db.getCollectionNames().sort().forEach(c => { const s = db.runCommand({collStats: c}); '
              'print("  " + c.padEnd(13) + String(s.count).padStart(8) + " docs " + '
              '(s.storageSize / 1048576).toFixed(1).padStart(6) + " MB on disk " + '
              '(s.totalIndexSize / 1048576).toFixed(1).padStart(6) + " MB indexes") })\'')
lines.append("Now in Atlas (marriott database):")
lines.append(check.stdout.rstrip() or check.stderr.strip())
print("\n".join(lines))
with open(HERE / "evidence" / "copy_to_atlas.txt", "a", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n\n")
