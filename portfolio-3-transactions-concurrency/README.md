# Portfolio 3: Transactions and Concurrency

**Case study:** Marriott International central reservation and Bonvoy database  
**DBMS:** PostgreSQL 16.4 in Docker

## 1. Why this matters for Marriott

Marriott's reservation system takes bookings from the website, the app, call centres, travel
agents and front desks all at once, for the same rooms. If two people try to book the last room
at the same moment, only one of them can get it. The Bonvoy loyalty system has the same problem
with points: a stay being credited and a redemption happening together must not lose either one.

Portfolio 2 already hinted at this. My generated data had 10 bookings for 8 Deluxe King rooms
at Lagos Marriott Ikeja, because the generator inserted bookings without checking availability.
This portfolio shows how that happens with real concurrent users, and how to stop it.

Study Session Two describes the four ACID properties, and its own example for Isolation is
airline booking systems, which is the same problem as hotel rooms. This portfolio tests each
property in practice.

## 2. Demo setup

[`00_reset_demo.sql`](00_reset_demo.sql) puts the data back to the same starting point before
every test:

* Lagos Marriott Hotel Ikeja has **4 Executive Suites**. For Christmas 2027 (24 to 27 December)
  three are already booked, so **one suite is left**.
* Two Bonvoy members: **Ifeoma** (member 300000001, 50,000 points) and **Daniel** (member
  300000002, 20,000 points).

To show two users at the same time, [`run_scenario.py`](run_scenario.py) starts two separate
database sessions (A and B), with B starting a fraction of a second after A, and prints one
timeline of what each did and when. A `pg_sleep(2)` in the scripts stands in for the guest
typing their card details, which is what leaves a gap for the other session to slip into.

## 3. Atomicity, consistency and rollback

[`01_acid_basics.sql`](01_acid_basics.sql), output in [`evidence/acid_basics.txt`](evidence/acid_basics.txt).

An award (points) booking changes three tables: it adds a reservation, adds a points
transaction, and lowers the member's balance. Portfolio 1 kept `points_balance` as a deliberate
denormalisation and promised that the balance and the transactions would always be updated
together. This is where that promise is kept.

| Test | What happens | Result |
|---|---|---|
| 1. Award booking, COMMIT | Ifeoma books 3 nights for 36,000 points | Booking saved, balance 50,000 → 14,000 |
| 2. Award booking that fails | Daniel (20,000 points) tries the same stay. The booking and the points record insert fine, then the balance update breaks `CHECK (points_balance >= 0)` | **Everything rolled back**: no booking, no points record, balance still 20,000 |
| 3. Explicit ROLLBACK | Guest closes the app before paying | The booking that was visible inside the transaction is gone |
| 4. SAVEPOINT | A card payment is entered without the card digits | `ROLLBACK TO SAVEPOINT` undoes only the bad payment; the booking stays and a correct payment is added |

Test 2 shows atomicity (all or nothing) and consistency (a constraint stopped the database
reaching an invalid state) working together. Without a transaction, Daniel would have a booking
and a points record but still have his 20,000 points.

## 4. Durability: crash test

[`durability_test.py`](durability_test.py), output in [`evidence/durability.txt`](evidence/durability.txt).

I committed a booking, then killed the database container with `SIGKILL`, which is like pulling
the power cable: no clean shutdown. After starting it again, the booking was still there.

The PostgreSQL log shows why:

```
07:40:04  checkpoint complete ...                      <- last time data files were written
07:40:26  booking P3DURABLE committed                  <- only in the write-ahead log (WAL)
07:40:28  container killed
07:40:34  database system was not properly shut down; automatic recovery in progress
07:40:34  redo starts at 0/5DDB9658
07:40:34  redo done at 0/5DDE0D38
07:40:34  database system is ready to accept connections
```

The booking was committed after the last checkpoint, so at the moment of the crash it only
existed in the write-ahead log. PostgreSQL writes every change to the WAL and flushes it to disk
before it reports `COMMIT`. On restart it replayed ("redo") the log and the booking came back.

## 5. Isolation: the last suite at Christmas

Ifeoma (session A) and Daniel (session B) both try to book the last suite. Each session checks
availability, waits while the guest "pays", then inserts the booking.

### READ COMMITTED (PostgreSQL's default): overbooked

[`evidence/overbook_rc.txt`](evidence/overbook_rc.txt)

```
  0.19s  A | [A] suites free: 1
  0.19s  A | [A] guest is paying...
  0.66s                        B | [B] suites free: 1
  0.66s                        B | [B] guest is paying...
  2.42s  A | COMMIT
  2.81s                        B | COMMIT

 suites_booked_for_christmas | suites_in_hotel
                           5 |               4
```

Both sessions saw one free suite, because neither had committed when the other checked. Both
bookings went through. **The hotel has sold 5 suites but only has 4.**

### REPEATABLE READ: still overbooked

[`evidence/overbook_rr.txt`](evidence/overbook_rr.txt). Same result, 5 bookings for 4 suites.

I expected the stricter level to fix it, but it does not. REPEATABLE READ stops a transaction
from seeing *changes to rows it has read*, but here each session inserts a *new, different*
row. There is no row both sessions changed, so nothing conflicts. This is called **write skew**:
each transaction is fine on its own, but together they break a rule (bookings must not exceed
rooms) that neither of them checked against the other.

### SERIALIZABLE: one booking cancelled

[`evidence/overbook_serializable.txt`](evidence/overbook_serializable.txt)

```
  2.43s  A | COMMIT
  2.84s                        B | ERROR:  could not serialize access due to read/write dependencies among transactions
  2.84s                        B | HINT:  The transaction might succeed if retried.
  2.84s                        B | ROLLBACK

 suites_booked_for_christmas | suites_in_hotel
                           4 |               4
```

At SERIALIZABLE, PostgreSQL tracks what each transaction *read* as well as what it wrote. It
noticed that B's availability check was based on data that A then changed, so the two could not
have run one after the other with the same result. It cancelled B. If the app retries B, the
retry sees 0 suites free and refuses the booking properly.

### SELECT ... FOR UPDATE: second guest waits, then is refused

[`book_suite_locking.sql`](book_suite_locking.sql), [`evidence/overbook_locking.txt`](evidence/overbook_locking.txt)

```
  0.20s  A | [A] locking the Executive Suite inventory...
  0.20s  A | [A] got the lock, checking availability...
  0.21s  A | [A] suites free: 1
  0.75s                        B | [B] locking the Executive Suite inventory...
  2.33s  A | COMMIT
  2.33s                        B | [B] got the lock, checking availability...
  2.34s                        B | [B] suites free: 0
  2.34s                        B | [B] sold out, booking refused
```

Here each booking first locks the room type row with `SELECT ... FOR UPDATE` (pessimistic
locking). B tried to take the lock at 0.75s and **waited 1.6 seconds** until A committed. When B
got the lock, its availability check ran after A's booking was saved, so it saw 0 suites and
refused. No error, no retry needed, and the hotel stays at 4 bookings for 4 suites.

### Which one would I use?

| Approach | Stops overbooking? | Cost |
|---|---|---|
| READ COMMITTED, check then insert | No | |
| REPEATABLE READ | No (write skew) | |
| SERIALIZABLE | Yes | The app must catch the error and retry. Some cancellations can be false alarms under heavy load. |
| FOR UPDATE on the room type | Yes | Bookings for the *same* room type at the same hotel queue up one at a time. Other room types and hotels are not affected. |

For the reservation system I would use **FOR UPDATE on the room type row**. The lock only
covers one room type at one hotel, so the queue is tiny: a few people at most will ever book the
same suite at the same second. It also gives the guest a clear "sold out" message instead of an
error. SERIALIZABLE would be a good choice for a system where many different rules need
protecting and writing a lock for each one is impractical.

Both fixes make some transactions wait or retry. Study Session Two makes the same point: strict
ACID guarantees can cost performance and scalability. For hotel inventory that cost is worth
paying, because selling a room twice means a guest arriving at Christmas with nowhere to sleep.

## 6. Lost update: Bonvoy points

Two things credit Ifeoma's account at the same time: 1,000 points for a stay (A) and a 2,500
point promotion (B). The naive code reads the balance, adds the points in the application, and
writes the new number back.

| Scenario | What happened | Final balance | Correct? |
|---|---|---|---|
| [`lost_update_rc`](evidence/lost_update_rc.txt) READ COMMITTED | Both read 50,000. A wrote 51,000, then B wrote 52,500 over it | 52,500 | **No, 1,000 points lost** |
| [`lost_update_rr`](evidence/lost_update_rr.txt) REPEATABLE READ | B got `could not serialize access due to concurrent update` and was rolled back | 51,000 | Safe, but B must retry |
| [`lost_update_fixed`](evidence/lost_update_fixed.txt) atomic `UPDATE ... SET points_balance = points_balance + 2500` | B waited for A's row lock, then added to the new value | 53,500 | **Yes** |

The READ COMMITTED result is the worst kind of bug: no error at all. The member silently loses
1,000 points, and the balance (52,500) no longer matches the points transactions (which add up
to 53,500). This is exactly the drift between `points_balance` and `points_transaction` that
Portfolio 1 warned about.

The fix is to let the database do the arithmetic. `points_balance = points_balance + 2500` reads
and writes in one step while holding the row lock, so the second update always works on the
latest value. [`earn_points_safe.sql`](earn_points_safe.sql)

## 7. Deadlock: members transferring points to each other

Bonvoy lets members transfer points. Ifeoma sends Daniel 5,000 points (A) while Daniel sends
Ifeoma 3,000 points (B) at the same time. Each transfer updates the sender first, then the receiver.

[`evidence/deadlock.txt`](evidence/deadlock.txt)

```
  0.17s  A | [A] taking 5000 points from 300000001          (A locks Ifeoma's row)
  0.58s                        B | [B] taking 3000 points from 300000002   (B locks Daniel's row)
  1.23s  A | [A] giving 5000 points to 300000002            (A waits for Daniel's row)
  1.63s                        B | [B] giving 3000 points to 300000001     (B waits for Ifeoma's row)
  2.32s  A | ERROR:  deadlock detected
  2.32s  A | DETAIL:  Process 1571 waits for ShareLock on transaction 1281; blocked by process 1579.
                       Process 1579 waits for ShareLock on transaction 1280; blocked by process 1571.
  2.32s                        B | COMMIT
```

Each session held one row and waited for the other's. Neither could ever finish. PostgreSQL
checks for this after waiting 1 second (`deadlock_timeout`), found the cycle, and cancelled A.
B then completed. The data stayed correct (A's transfer was fully undone), but Ifeoma's transfer
failed and would need retrying.

**Fix:** [`transfer_points_ordered.sql`](transfer_points_ordered.sql) locks both accounts first,
always in member number order:

```sql
SELECT member_number FROM bonvoy_account
WHERE member_number IN (:'from_member', :'to_member')
ORDER BY member_number
FOR UPDATE;
```

Now both transfers try to lock 300000001 first. B simply waits for A to finish, then runs. Both
transfers succeed and the balances are right (Ifeoma 50,000 − 5,000 + 3,000 = 48,000, Daniel
20,000 + 5,000 − 3,000 = 22,000). [`evidence/deadlock_fixed.txt`](evidence/deadlock_fixed.txt)

## 8. Non-repeatable read: a rate change during a report

A revenue manager's report reads the Executive Suite rate twice in one transaction. Between the
two reads, someone else raises the Christmas rate from 573,500 to 650,000.

| Isolation level | First read | Second read |
|---|---|---|
| [READ COMMITTED](evidence/nonrepeatable_rc.txt) | 573,500 | **650,000** |
| [REPEATABLE READ](evidence/nonrepeatable_rr.txt) | 573,500 | 573,500 |

Under READ COMMITTED each statement sees the latest committed data, so the same question gave
two different answers inside one report. A report that totals revenue in one query and lists
rates in another could disagree with itself. REPEATABLE READ gives the whole transaction one
snapshot, so the report is consistent. That makes it the right level for reports that run
several queries.

## 9. Summary

| ACID property | How I tested it | Result |
|---|---|---|
| Atomicity | Award booking that fails at the third step | All three changes undone |
| Consistency | `CHECK (points_balance >= 0)` inside a transaction | Invalid state blocked, transaction rolled back |
| Isolation | Last suite, lost update, non-repeatable read at different levels | Problems at weaker levels, fixed with locking, atomic updates or stronger levels |
| Durability | Committed booking, then killed the database | Booking recovered from the write-ahead log |

| Concurrency problem | Fix I would use |
|---|---|
| Overbooking (write skew) | `SELECT ... FOR UPDATE` on the room type, or SERIALIZABLE with retry |
| Lost update on points | Atomic `UPDATE ... SET x = x + n` |
| Deadlock on transfers | Lock rows in a fixed order |
| Non-repeatable read in reports | REPEATABLE READ for multi-query reports |

## 10. How to run it

```bash
# from the repository root, with Portfolios 1 and 2 already loaded
docker exec marriott_postgres sh -c "psql -U mit8103 -d marriott_crs -f /scripts/p3/01_acid_basics.sql 2>&1"
python portfolio-3-transactions-concurrency/durability_test.py
python portfolio-3-transactions-concurrency/run_scenario.py list          # shows all scenarios
python portfolio-3-transactions-concurrency/run_scenario.py overbook_rc   # runs one
```

| File | Purpose |
|---|---|
| `00_reset_demo.sql` | Puts the demo data back to the starting point (one suite left, fixed balances) |
| `01_acid_basics.sql` | Commit, automatic rollback, explicit rollback, savepoint |
| `durability_test.py` | Commit, kill the database, restart, check |
| `run_scenario.py` | Runs two sessions at once and prints the timeline |
| `book_suite_unsafe.sql` / `book_suite_locking.sql` | Last suite booking, naive and with `FOR UPDATE` |
| `earn_points_unsafe.sql` / `earn_points_safe.sql` | Points credit, read then write vs atomic update |
| `transfer_points.sql` / `transfer_points_ordered.sql` | Points transfer, with and without ordered locking |
| `rate_report.sql` / `rate_change.sql` | Non-repeatable read test |
| `evidence/` | Saved output of every test |

## References

- MIVA Open University (2025) *MIT 8103 Advanced Database Systems*. Course material, Study Session Two (ACID model, 2.2.1.2 and 2.2.2.2).
- PostgreSQL Global Development Group (2024) *PostgreSQL 16 Documentation: Transaction Isolation*. Available at: https://www.postgresql.org/docs/16/transaction-iso.html
- PostgreSQL Global Development Group (2024) *PostgreSQL 16 Documentation: Explicit Locking*. Available at: https://www.postgresql.org/docs/16/explicit-locking.html
- PostgreSQL Global Development Group (2024) *PostgreSQL 16 Documentation: Write-Ahead Logging (WAL)*. Available at: https://www.postgresql.org/docs/16/wal-intro.html
