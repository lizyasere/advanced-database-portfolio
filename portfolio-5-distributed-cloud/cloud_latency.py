# Portfolio 5: run 06_cloud_latency.js against the local replica set and against MongoDB Atlas.
# The Atlas connection string is read from atlas-credentials.env inside a throwaway container.
#
# usage:  python cloud_latency.py [local|atlas|both]   (needs the replica profile for local)
# output: evidence/cloud_latency.txt

import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).parent.resolve()
LOCAL = "mongodb://rs1:27017,rs2:27017,rs3:27017/?replicaSet=rs0"


def local():
    return subprocess.run(["docker", "exec", "p5_rs1", "mongosh", "--quiet", LOCAL,
                           "/scripts/p5/06_cloud_latency.js"], capture_output=True, text=True)


def atlas():
    return subprocess.run(["docker", "run", "--rm",
                           "--mount", f"type=bind,src={HERE / 'atlas-credentials.env'},dst=/run/atlas.env,readonly",
                           "--mount", f"type=bind,src={HERE / '06_cloud_latency.js'},dst=/run/test.js,readonly",
                           "mongo:7.0.14", "sh", "-c",
                           'set -a; . /run/atlas.env; set +a; mongosh --quiet "$MONGODB_URI" /run/test.js'],
                          capture_output=True, text=True)


which = sys.argv[1] if len(sys.argv) > 1 else "both"
runs = {"local": [local], "atlas": [atlas], "both": [local, atlas]}[which]
lines = [f"Run at {datetime.now(timezone.utc):%Y-%m-%d %H:%M} UTC from my laptop"]
for run in runs:
    out = run()
    lines.append("")
    lines.append((out.stdout + out.stderr).rstrip())
print("\n".join(lines))
(HERE / "evidence" / "cloud_latency.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
