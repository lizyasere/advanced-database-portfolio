# Portfolio 3: runs two database sessions at the same time and prints one
# timeline showing what each session did and when.
#
# usage:  python run_scenario.py <scenario>      e.g.  python run_scenario.py overbook_rc
#         python run_scenario.py list
# output: printed timeline, also saved to evidence/<scenario>.txt

import subprocess
import sys
import threading
import time
from pathlib import Path

HERE = Path(__file__).parent
PSQL = "psql -U mit8103 -d marriott_crs"

BOOKING_CHECK = """SELECT r.confirmation_no, g.first_name || ' ' || g.last_name AS guest
FROM crs.reservation r JOIN crs.guest g USING (guest_id)
WHERE r.confirmation_no LIKE 'P3%' ORDER BY r.confirmation_no;
SELECT count(*) AS suites_booked_for_christmas, 4 AS suites_in_hotel
FROM crs.reservation r JOIN crs.room_type rt USING (room_type_id) JOIN crs.hotel h ON h.hotel_id = rt.hotel_id
WHERE h.marsha_code = 'LOSMC' AND rt.type_code = 'EXSU' AND r.res_status IN ('Confirmed', 'Checked In')
  AND r.check_in_date < DATE '2027-12-27' AND r.check_out_date > DATE '2027-12-24';"""

POINTS_CHECK = """SELECT ba.points_balance AS final_balance,
       50000 + COALESCE(sum(pt.points), 0) AS start_plus_transactions
FROM crs.bonvoy_account ba LEFT JOIN crs.points_transaction pt USING (account_id)
WHERE ba.member_number = '300000001' GROUP BY ba.points_balance;"""

TRANSFER_CHECK = """SELECT member_number, points_balance FROM crs.bonvoy_account
WHERE member_number IN ('300000001', '300000002') ORDER BY member_number;"""

A_BOOK = "-v who=A -v conf=P3A0001 -v email=ifeoma.chukwu@example.com"
B_BOOK = "-v who=B -v conf=P3B0001 -v email=daniel.okoro@example.com"

# name: (description, session A, session B, seconds B starts after A, final check)
SCENARIOS = {
    "overbook_rc": ("Last suite, naive booking, READ COMMITTED",
                    f"{A_BOOK} -v iso='READ COMMITTED' -f /scripts/p3/book_suite_unsafe.sql",
                    f"{B_BOOK} -v iso='READ COMMITTED' -f /scripts/p3/book_suite_unsafe.sql",
                    0.5, BOOKING_CHECK),
    "overbook_rr": ("Last suite, naive booking, REPEATABLE READ",
                    f"{A_BOOK} -v iso='REPEATABLE READ' -f /scripts/p3/book_suite_unsafe.sql",
                    f"{B_BOOK} -v iso='REPEATABLE READ' -f /scripts/p3/book_suite_unsafe.sql",
                    0.5, BOOKING_CHECK),
    "overbook_serializable": ("Last suite, naive booking, SERIALIZABLE",
                    f"{A_BOOK} -v iso=SERIALIZABLE -f /scripts/p3/book_suite_unsafe.sql",
                    f"{B_BOOK} -v iso=SERIALIZABLE -f /scripts/p3/book_suite_unsafe.sql",
                    0.5, BOOKING_CHECK),
    "overbook_locking": ("Last suite, booking with SELECT ... FOR UPDATE",
                    f"{A_BOOK} -f /scripts/p3/book_suite_locking.sql",
                    f"{B_BOOK} -f /scripts/p3/book_suite_locking.sql",
                    0.5, BOOKING_CHECK),
    "lost_update_rc": ("Two points updates on one balance, read then write, READ COMMITTED",
                    "-v who=A -v points=1000 -v iso='READ COMMITTED' -f /scripts/p3/earn_points_unsafe.sql",
                    "-v who=B -v points=2500 -v iso='READ COMMITTED' -f /scripts/p3/earn_points_unsafe.sql",
                    0.5, POINTS_CHECK),
    "lost_update_rr": ("Two points updates on one balance, read then write, REPEATABLE READ",
                    "-v who=A -v points=1000 -v iso='REPEATABLE READ' -f /scripts/p3/earn_points_unsafe.sql",
                    "-v who=B -v points=2500 -v iso='REPEATABLE READ' -f /scripts/p3/earn_points_unsafe.sql",
                    0.5, POINTS_CHECK),
    "lost_update_fixed": ("Two points updates on one balance, atomic UPDATE",
                    "-v who=A -v points=1000 -f /scripts/p3/earn_points_safe.sql",
                    "-v who=B -v points=2500 -f /scripts/p3/earn_points_safe.sql",
                    0.5, POINTS_CHECK),
    "deadlock": ("Two members transfer points to each other at the same time",
                    "-v who=A -v from_member=300000001 -v to_member=300000002 -v points=5000 -f /scripts/p3/transfer_points.sql",
                    "-v who=B -v from_member=300000002 -v to_member=300000001 -v points=3000 -f /scripts/p3/transfer_points.sql",
                    0.3, TRANSFER_CHECK),
    "deadlock_fixed": ("Same transfers, both accounts locked in a fixed order",
                    "-v who=A -v from_member=300000001 -v to_member=300000002 -v points=5000 -f /scripts/p3/transfer_points_ordered.sql",
                    "-v who=B -v from_member=300000002 -v to_member=300000001 -v points=3000 -f /scripts/p3/transfer_points_ordered.sql",
                    0.3, TRANSFER_CHECK),
    "nonrepeatable_rc": ("Report reads the suite rate twice while it changes, READ COMMITTED",
                    "-v who=A -v iso='READ COMMITTED' -f /scripts/p3/rate_report.sql",
                    "-v who=B -f /scripts/p3/rate_change.sql",
                    0.7, None),
    "nonrepeatable_rr": ("Report reads the suite rate twice while it changes, REPEATABLE READ",
                    "-v who=A -v iso='REPEATABLE READ' -f /scripts/p3/rate_report.sql",
                    "-v who=B -f /scripts/p3/rate_change.sql",
                    0.7, None),
}


def psql(args):
    # -t gives psql a terminal, so it prints each line straight away
    return ["docker", "exec", "-t", "marriott_postgres", "sh", "-c", f"{PSQL} {args} 2>&1"]


def run_quiet(sql):
    out = subprocess.run(["docker", "exec", "marriott_postgres", "sh", "-c", f"{PSQL} -c \"{sql}\" 2>&1"],
                         capture_output=True, text=True)
    return out.stdout


def main():
    name = sys.argv[1] if len(sys.argv) > 1 else "list"
    if name not in SCENARIOS:
        print("scenarios:\n  " + "\n  ".join(f"{k:24} {v[0]}" for k, v in SCENARIOS.items()))
        return
    title, a_args, b_args, delay, check = SCENARIOS[name]

    subprocess.run(["docker", "exec", "marriott_postgres", "sh", "-c",
                    f"{PSQL} -q -f /scripts/p3/00_reset_demo.sql 2>&1"], capture_output=True)

    events, lock = [], threading.Lock()
    start = time.time()

    def session(label, args, wait):
        time.sleep(wait)
        proc = subprocess.Popen(psql(args), stdout=subprocess.PIPE, text=True, encoding="utf-8")
        for line in proc.stdout:
            line = line.rstrip("\r\n")
            if line.strip():
                with lock:
                    events.append((time.time() - start, label, line))
        proc.wait()

    threads = [threading.Thread(target=session, args=("A", a_args, 0)),
               threading.Thread(target=session, args=("B", b_args, delay))]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    lines = [f"Scenario: {name}  ({title})", f"Session B starts {delay}s after session A", ""]
    for t, label, text in sorted(events):
        indent = "" if label == "A" else " " * 46
        lines.append(f"{t:6.2f}s  {indent}{label} | {text}")
    if check:
        lines += ["", "Result after both sessions finished:", run_quiet(check).rstrip()]

    report = "\n".join(lines)
    print(report)
    (HERE / "evidence").mkdir(exist_ok=True)
    (HERE / "evidence" / f"{name}.txt").write_text(report + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
