# Reflection Notes

## Choosing the case study and setting up

My first idea was a made-up hotel chain, because it would be simple to control. I changed to
Marriott International because a real company gave me real problems to design around. Marriott's
history lined up with almost every topic in the course: the old MARSHA reservation system on a
mainframe, the partial move to NoSQL, the new cloud reservation system, and the Starwood data
breach. Using one organisation all the way through also forced me to keep my design consistent
from one portfolio to the next.

I ran everything in Docker instead of installing PostgreSQL and MongoDB directly. The first
problem came straight away: port 5432 was already being used by another project's database on
my laptop, so my container would not start. I moved my PostgreSQL to port 5433 rather than
touching the other project. It was a small thing, but it showed me why containers are useful:
two databases can run side by side without interfering with each other.

## Portfolio 1: Database design and modelling

**Design choices.** The decision I thought about most was whether a reservation should point at
a specific room or a room type. Guests book a "Deluxe King", not "room 402", so I made the
reservation store the room type and created a separate `stay` table that records the actual
room at check-in. This matches how hotels really work, and it also sets up the overbooking
problem I deal with in Portfolio 3.

I used surrogate keys (SERIAL) as primary keys and kept natural identifiers like email and the
MARSHA code as UNIQUE columns. I also chose to keep two values that could be calculated
(`nightly_rate` and `points_balance`) because one is a historical price and the other would be
too slow to recalculate for millions of members. Learning to explain why a "redundant" column
is actually a separate fact was one of the more useful parts of this stage.

**Challenges.** My constraint tests first ran with the output in the wrong order, so Test 4's
error appeared under Test 5's heading. It turned out PowerShell prints normal output and error
messages separately. Running psql through `sh -c "... 2>&1"` inside the container fixed it.

The bigger issue came from Test 2. I had reused an Abuja booking to test a room in Accra. The
overlap constraint did reject it, but it made me realise that nothing stopped a guest from being
checked into a room in a completely different hotel from the one they booked. A CHECK constraint
could not catch this because it cannot read other tables, so I wrote a trigger and added Test 10
to prove it worked. I would not have found this gap if I had only tested with correct data.

**What I learned.**
* Constraints are cheaper than application code for protecting data, because the database
  enforces them for every program that connects to it.
* PostgreSQL's `EXCLUDE` constraint with date ranges can stop double occupancy of a room, which
  a normal UNIQUE constraint cannot do.
* SERIAL IDs skip numbers when an insert fails or is rolled back. I noticed reservation 19 in my
  failed tests when there were only 14 bookings, and found out this is by design so concurrent
  inserts do not block each other.
* Security is a design decision, not an afterthought. After reading about the Starwood breach, I
  decided not to store passport numbers or full card numbers at all.

## Portfolio 2: Query processing and optimisation

**Design choices.** With only 14 bookings, every query was instant, so I wrote a generator for
one million bookings across 198 hotels. I fixed the random seed and fixed "today" at 12 November
2026 so the data comes out the same every run. I picked five queries that different people at
Marriott would actually run, from the booking website to the front desk to the loyalty team.

**Challenges.** The generator failed twice before it worked: once because `row_number()` returns
a bigint and `chr()` needs an integer, and once because `round(value, 2)` does not accept the
double precision type that `random()` produces. Both were fixed with explicit casts. A full run
also takes about five minutes, which made mistakes expensive, so I learned to test small parts
before running the whole thing.

My first timings were unreliable. Q1 took 136 ms on one run and 215 ms on the next, so a single
before-and-after comparison could have been misleading. I wrote a small Python script that runs
every query five times and records the median.

The most interesting problem was Q5 (top Bonvoy members). I added an index expecting it to
help, and PostgreSQL did use it, but the query was no faster. Reading the plan showed the real
cost was sorting 85,000 members on disk just to keep the top 10. My first rewrite with RANK()
was still slow, because the planner thought 83,000 rows would come out and joined the whole
guest table. Changing to `FETCH FIRST 10 ROWS WITH TIES` told the planner only about 10 rows
were coming, and it switched to a much cheaper plan. That took Q5 from about 567 ms to about
150 ms.

**What I learned.**
* Read the plan before adding an index. The plan tells you whether the time is spent finding
  rows (an index helps) or processing them (a rewrite helps).
* Wrapping a column in a function, like `EXTRACT(YEAR FROM check_in_date)`, hides it from the
  planner. It guessed 1,517 rows when there were 73,418. Writing the same filter as a date range
  fixed the estimate.
* One well designed index can serve more than one query. `(hotel_id, check_in_date)` sped up
  both the revenue report and the front desk arrivals list. Column order matters.
* Indexes have a cost. Inserts were about 25% slower with the new indexes, and the points index
  took 13 MB for almost no gain, so I would not keep it in production.
* My existing UNIQUE index on email could not help a search on `lower(email)`. Fixing that also
  closed a design gap from Portfolio 1, where `Ada@x.com` and `ada@x.com` could have been
  registered as two different guests.
* Q1 showed 10 bookings for 8 rooms, because my generator never checked availability. That is
  the same thing that happens when two real booking requests check at the same moment, which is
  what Portfolio 3 is about.
