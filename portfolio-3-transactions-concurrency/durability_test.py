# Portfolio 3: durability test.
# 1. commit a booking  2. kill the database container instantly (like a power cut)
# 3. start it again    4. check the booking is still there and show the recovery log
#
# usage:  python durability_test.py
# output: evidence/durability.txt

import subprocess
import time
from pathlib import Path

HERE = Path(__file__).parent
PSQL = ["docker", "exec", "marriott_postgres", "psql", "-U", "mit8103", "-d", "marriott_crs"]
lines = []


def log(text=""):
    print(text)
    lines.append(text)


def sql(query):
    out = subprocess.run(PSQL + ["-c", query], capture_output=True, text=True)
    return (out.stdout + out.stderr).rstrip()


log("Step 1: commit a booking")
log(sql("DELETE FROM crs.reservation WHERE confirmation_no = 'P3DURABLE';"))
log(sql("""INSERT INTO crs.reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
               check_in_date, check_out_date, num_guests, nightly_rate, booking_channel)
           SELECT 'P3DURABLE', g.guest_id, rt.hotel_id, rt.room_type_id, 1,
                  DATE '2027-08-01', DATE '2027-08-04', 2, rt.base_rate, 'Web'
           FROM crs.guest g, crs.room_type rt JOIN crs.hotel h USING (hotel_id)
           WHERE g.email = 'ifeoma.chukwu@example.com' AND h.marsha_code = 'LOSSI' AND rt.type_code = 'DLXK';"""))
log(sql("SELECT confirmation_no, booked_at FROM crs.reservation WHERE confirmation_no = 'P3DURABLE';"))

log("")
log("Step 2: kill the database container immediately (SIGKILL, no clean shutdown)")
# read the time from the database's own clock, so it can be compared with booked_at
# (the laptop clock and the Docker clock can be a second or two apart)
log(sql("SELECT clock_timestamp() AS database_time_just_before_kill;"))
subprocess.run(["docker", "kill", "--signal", "KILL", "marriott_postgres"], capture_output=True)
log("container killed")

log("")
log("Step 3: start it again")
subprocess.run(["docker", "start", "marriott_postgres"], capture_output=True)
for _ in range(60):
    ready = subprocess.run(["docker", "exec", "marriott_postgres", "pg_isready", "-U", "mit8103"],
                           capture_output=True, text=True)
    if ready.returncode == 0:
        break
    time.sleep(1)
log("database is accepting connections again")

log("")
log("Step 4: is the booking still there?")
log(sql("SELECT confirmation_no, booked_at FROM crs.reservation WHERE confirmation_no = 'P3DURABLE';"))

log("")
log("PostgreSQL startup log after the crash:")
logs = subprocess.run(["docker", "logs", "--since", "2m", "marriott_postgres"], capture_output=True, text=True)
for line in (logs.stdout + logs.stderr).splitlines():
    if any(word in line for word in ["interrupted", "not properly shut down", "redo", "automatic recovery",
                                     "checkpoint complete", "ready to accept"]):
        log("  " + line.strip())

(HERE / "evidence" / "durability.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
