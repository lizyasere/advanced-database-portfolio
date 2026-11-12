# Portfolio 4: 10 guests try to book the last Executive Suite at LOSMC (24 to 27 Dec 2027)
# at the same time, first with read-then-write, then with the atomic conditional update.
# Run 05_availability_kv.js first (it builds the availability keys).
#
# usage:  python race_availability.py
# output: evidence/race_availability.txt

import subprocess
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).parent
GUESTS = 10
lines = []


def log(text=""):
    print(text)
    lines.append(text)


def mongo(js):
    out = subprocess.run(["docker", "exec", "marriott_mongo", "mongosh", "--quiet", "--eval",
                          'load("/scripts/p4/kv_book.js"); db = db.getSiblingDB("marriott"); ' + js],
                         capture_output=True, text=True)
    return out.stdout.strip()


RESET = r'db.availability.updateMany({_id: /^LOSMC|EXSU|2027-12-2[456]/}, {$set: {sold: 3}});'
STATE = (r'print(db.availability.find({_id: /^LOSMC|EXSU|2027-12-2[456]/}).sort({_id: 1}).toArray()'
         r'.map(d => d._id.slice(-10) + " sold " + d.sold + " of " + d.total).join(", "))')

for name, fn in [("read then write", "bookUnsafe"), ("atomic conditional update", "book")]:
    mongo(RESET)
    log(f"=== {name}: {GUESTS} guests, 1 suite left ===")
    log("before: " + mongo(STATE))
    call = f'print(JSON.stringify({fn}("LOSMC", "EXSU", new Date(Date.UTC(2027, 11, 24)), 3)))'
    with ThreadPoolExecutor(GUESTS) as pool:
        results = list(pool.map(lambda _: mongo(call), range(GUESTS)))
    booked = sum('"ok":true' in r for r in results)
    log(f"guests told 'booked': {booked}")
    log("after:  " + mongo(STATE))
    log("")

mongo(RESET)
(HERE / "evidence" / "race_availability.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
