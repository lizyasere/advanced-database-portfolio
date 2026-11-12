# Portfolio 5: what happens to bookings when the primary fails.
#   Test 1: the primary is killed (like a server crash).
#   Test 2: the primary is cut off from the network (a partition), but keeps running.
# A booking writer runs in its own container the whole time, so every timestamp comes from
# one clock.
#
# usage:  python failover_test.py [failover|partition]
# output: evidence/failover.txt, evidence/partition.txt

import json
import subprocess
import threading
import time
from pathlib import Path

HERE = Path(__file__).parent
NETWORK = "portfolio-5-distributed-cloud_p5net"


def sh(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout.strip()


def member_states(via="p5_rs1"):
    return sh("docker", "exec", via, "mongosh", "--quiet", "--eval",
              'rs.status().members.map(m => m.name.split(":")[0] + " " + m.stateStr).join(", ")')


def primary():
    for _ in range(30):
        for node in ["p5_rs1", "p5_rs2", "p5_rs3"]:
            name = sh("docker", "exec", node, "mongosh", "--quiet", "--eval",
                      'db.hello().primary ? db.hello().primary.split(":")[0] : ""')
            if name:
                return name
        time.sleep(1)


def election_log(node, since):
    # what the new primary wrote in its own log while it took over
    keep = ["Starting an election", "Election succeeded", "Transition to primary complete",
            "Stepping down", "can't see a majority"]
    raw = subprocess.run(["docker", "logs", "--since", since, f"p5_{node}"], capture_output=True, text=True)
    rows = []
    for line in (raw.stdout + raw.stderr).splitlines():
        try:
            j = json.loads(line)
        except ValueError:
            continue
        if any(k in j.get("msg", "") for k in keep):
            rows.append(f"    {j['t']['$date'][11:23]} {node}: {j['msg']}")
    return rows


def start_writer(seconds):
    return subprocess.Popen(["docker", "run", "--rm", "--network", NETWORK, "-e", f"SECONDS={seconds}",
                             "-v", f"{HERE.resolve()}:/scripts/p5", "mongo:7.0.14",
                             "mongosh", "--quiet", "--nodb", "/scripts/p5/booking_writer.js"],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def stamp():
    # time from inside the Docker network, the same clock the writer uses
    for node in ["p5_rs1", "p5_rs2", "p5_rs3"]:
        r = subprocess.run(["docker", "exec", node, "date", "-u", "+%H:%M:%S.%3N"], capture_output=True, text=True)
        if r.returncode == 0:
            return r.stdout.strip()


def run(name, action, undo, seconds=40):
    out = []
    target = primary()
    started = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    out.append(f"before: {member_states()}")
    writer = start_writer(seconds)
    log = []
    reader = threading.Thread(target=lambda: log.extend(iter(writer.stdout.readline, "")))
    reader.start()
    while sum("saved" in l for l in log) < 10:     # let the app run normally first
        time.sleep(0.2)
    action[1](target)
    out.append(f">>> {stamp()} {action[0]} {target}")
    time.sleep(15)
    survivor = "p5_rs1" if target != "rs1" else "p5_rs2"
    out.append(f">>> {stamp()} states seen by the others: {member_states(survivor)}")
    if name == "partition":
        alone = sh("docker", "exec", f"p5_{target}", "mongosh", "--quiet", "--eval",
                   'db.hello().isWritablePrimary ? "still PRIMARY" : "stepped down, not accepting writes"')
        out.append(f">>> {stamp()} the cut-off node {target} says: {alone}")
    undo(target)
    out.append(f">>> {stamp()} {target} is back")
    writer.wait()
    reader.join()
    log = [l.rstrip() for l in log]
    time.sleep(5)
    out.append(f"after:  {member_states(survivor)}")
    new_primary = primary()
    out.append(f"log of the new primary {new_primary} (and of {target}):")
    out.extend(election_log(new_primary, started) + election_log(target, started))
    text = "\n".join(out[:2] + log + out[2:]) if False else None
    # merge: writer lines in time order with the >>> markers
    events = sorted([l for l in log if l[:2].isdigit()] + [o for o in out if o.startswith(">>>")],
                    key=lambda l: l.replace(">>> ", "")[:12])
    tail = out[out.index(next(o for o in out if o.startswith("after:"))):]
    lines = [out[0]] + events + [l for l in log if l.startswith("saved")] + tail
    failed = sum("FAILED" in l for l in log)
    lines.append(f"failed attempts: {failed}")
    (HERE / "evidence" / f"{name}.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines) + "\n")


import sys
which = sys.argv[1] if len(sys.argv) > 1 else "both"

if which in ("failover", "both"):
  run("failover",
    ("killed the primary:", lambda p: sh("docker", "kill", f"p5_{p}")),
    lambda p: (sh("docker", "start", f"p5_{p}"), time.sleep(20)))

if which in ("partition", "both"):
  run("partition",
    ("cut the primary off the network:", lambda p: sh("docker", "network", "disconnect", NETWORK, f"p5_{p}")),
    lambda p: (sh("docker", "network", "connect", "--alias", p, NETWORK, f"p5_{p}"), time.sleep(20)))
