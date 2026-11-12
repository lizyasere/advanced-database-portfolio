# Portfolio 4: copy the Marriott data from PostgreSQL into MongoDB.
# PostgreSQL builds each document as one line of JSON (see export/*.sql) and the output
# is streamed straight into mongoimport, so no large files are written to disk.
#
# usage:  python load_mongo.py
# output: evidence/load_mongo.txt

import subprocess
import time
from pathlib import Path

HERE = Path(__file__).parent
lines = []


def log(text=""):
    print(text)
    lines.append(text)


def mongosh(script):
    out = subprocess.run(["docker", "exec", "marriott_mongo", "mongosh", "--quiet", script],
                         capture_output=True, text=True)
    return (out.stdout + out.stderr).strip()


log(mongosh("/scripts/p4/01_create_collections.js"))

for collection in ["hotels", "guests", "reservations"]:
    start = time.time()
    export = subprocess.Popen(
        ["docker", "exec", "marriott_postgres", "psql", "-U", "mit8103", "-d", "marriott_crs",
         "-At", "-q", "-f", f"/scripts/p4/export/{collection}.sql"],
        stdout=subprocess.PIPE)
    load = subprocess.run(
        ["docker", "exec", "-i", "marriott_mongo", "mongoimport", "--quiet", "--db", "marriott",
         "--collection", collection, "--numInsertionWorkers", "2"],
        stdin=export.stdout, capture_output=True, text=True)
    export.wait()
    if load.returncode != 0:
        log(load.stderr)
        raise SystemExit(f"loading {collection} failed")
    log(f"{collection}: loaded in {time.time() - start:.0f} s")

log(mongosh("/scripts/p4/02_create_indexes.js"))
log(mongosh("/scripts/p4/03_check_load.js"))

(HERE / "evidence").mkdir(exist_ok=True)
(HERE / "evidence" / "load_mongo.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
