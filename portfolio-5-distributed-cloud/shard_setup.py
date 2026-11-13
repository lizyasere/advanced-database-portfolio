# Portfolio 5: build the sharded cluster and load the upcoming bookings into it.
# Start it first:  docker compose --profile sharded up -d
#
# usage:  python shard_setup.py
# output: evidence/shard_setup.txt

import subprocess
import time
from pathlib import Path

HERE = Path(__file__).parent
lines = []


def mongosh(container, js, uri=None):
    cmd = ["docker", "exec", container, "mongosh", "--quiet"] + ([uri] if uri else []) + ["--eval", js]
    out = subprocess.run(cmd, capture_output=True, text=True)
    return (out.stdout + out.stderr).strip()


def log(text):
    print(text)
    lines.append(text)


# 1. each shard and the config server is a (one node) replica set
for container, rs_id, extra in [("p5_cfg", "cfgrs", "configsvr: true, "),
                                ("p5_shard_emea", "emea", ""), ("p5_shard_amer", "amer", "")]:
    host = container.replace("p5_", "")
    mongosh(container, f'try {{ rs.initiate({{ _id: "{rs_id}", {extra}members: [{{ _id: 0, host: "{host}:27017" }}] }}) }} catch (e) {{}}')
for container in ["p5_cfg", "p5_shard_emea", "p5_shard_amer"]:
    while "true" not in mongosh(container, "db.hello().isWritablePrimary"):
        time.sleep(1)
while "ok" not in mongosh("p5_mongos", 'db.adminCommand({ping: 1}).ok ? "ok" : ""'):
    time.sleep(1)

# 2. shards, zones and the shard key
config_out = mongosh("p5_mongos", 'load("/scripts/p5/04_shard_config.js")')
log("\n".join(line for line in config_out.splitlines() if line != "true"))

# 3. upcoming bookings, with the hotel's region added as a top level field for the shard key
mongosh("marriott_mongo", """
db = db.getSiblingDB("marriott");
db.reservations.aggregate([
  { $match: { check_in: { $gte: ISODate("2026-11-12") } } },
  { $lookup: { from: "hotels", localField: "hotel.code", foreignField: "_id", as: "h" } },
  { $set: { region: { $first: "$h.location.region" } } },
  { $unset: "h" },
  { $out: "reservations_by_region" } ]);
""")
start = time.time()
dump = subprocess.Popen(["docker", "exec", "marriott_mongo", "mongodump", "--quiet", "--archive",
                         "--db", "marriott", "--collection", "reservations_by_region"], stdout=subprocess.PIPE)
restore = subprocess.run(["docker", "exec", "-i", "p5_mongos", "mongorestore", "--quiet", "--archive",
                          "--nsFrom", "marriott.reservations_by_region", "--nsTo", "marriott.reservations",
                          "--noIndexRestore"], stdin=dump.stdout, capture_output=True, text=True)
dump.wait()
mongosh("marriott_mongo", 'db.getSiblingDB("marriott").reservations_by_region.drop()')
if restore.returncode != 0:
    raise SystemExit(restore.stderr)
log(f"loaded the upcoming bookings through mongos in {time.time() - start:.0f} s")

(HERE / "evidence" / "shard_setup.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
