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

## Portfolio 3: Transactions and concurrency

**Design choices.** I wanted to show concurrency problems actually happening, not just describe
them. A single psql window cannot do that, because one session cannot race against itself. I
wrote a small Python runner that starts two database sessions a fraction of a second apart and
prints one combined timeline. A two second `pg_sleep` stands in for a guest typing their card
details, which gives the second session time to slip in. I kept the story to one hotel and one
night that matters: the last Executive Suite at Lagos Marriott Ikeja for Christmas.

For durability I could have just restarted the database, but a clean restart writes everything
to disk first, so it would not prove much. Killing the container with SIGKILL is closer to a
power cut.

**Challenges.** The scripts needed to make a decision half way through ("if a suite is free,
book it, otherwise refuse"). I used psql's `\gset` to store the availability count in a variable
and `\if` to branch on it, which I had not used before.

My demo data also needed to start from the same point every time, otherwise the second run of a
scenario would find the suite already taken by the first run. I wrote a reset script that the
runner calls before every scenario. I first put the wrong base rate in it (572,000 instead of
573,500), which I only noticed when I checked the real value in the table.

When I took the screenshot of the crash test, the times looked wrong: converted to the same time
zone, the container was "killed" one second before the booking was committed. The kill time came
from my laptop's clock and the booking time from the database inside Docker, and the two clocks
were about a second apart. I changed the script to read the time from the database just before
the kill, so both times come from the same clock. It taught me to be careful when comparing
timestamps from different machines, which matters even more in a distributed database.

**What I learned.**
* REPEATABLE READ did not stop the overbooking. Each session inserted a different row, so there
  was nothing for the database to see as a conflict. This is write skew, and it showed me that
  a "stricter" isolation level is not automatically safe. You have to know which anomaly each
  level prevents.
* The lost update was the most worrying result because there was no error at all. Ifeoma just
  ended up 1,000 points short, and the balance no longer matched her transactions. If I had not
  compared the two, I would never have known.
* Letting the database do the arithmetic (`points_balance = points_balance + 2500`) fixed the
  lost update with one small change, without needing a stricter isolation level.
* PostgreSQL found the deadlock by itself after about one second and cancelled one transfer, so
  the data stayed correct. But the user still gets an error, so the real fix is to always lock
  rows in the same order.
* The crash test made the write-ahead log real for me. The booking was committed after the last
  checkpoint, so it only existed in the WAL when I killed the database, and the recovery log
  showed it being replayed.
* Every fix has a cost. Locking makes people queue and SERIALIZABLE needs retries. For hotel
  rooms I think queuing is the right price, because the alternative is a guest with no room.

## Portfolio 4: NoSQL and advanced data models

**Design choices.** I used the same million bookings from Portfolio 2 instead of a small new
sample, so I could compare the models fairly. Rather than writing a separate converter, I made
PostgreSQL build each MongoDB document as a line of JSON and streamed it straight into
`mongoimport`. That way nothing large was saved on my laptop, and dates and money arrived as
real dates and exact decimals instead of text.

The hardest part of the document model was deciding what to embed. I embedded room types in
hotels, the Bonvoy account in the guest, and payments and points in the booking, because each of
those belongs to one parent and is always shown with it. I did not embed a guest's full booking
history, only the last three, because a frequent traveller could have hundreds of bookings and
the document would keep growing.

I used three models instead of one: documents for the app screens, a key-value store for room
availability, and Neo4j for the graph, because Study Session Five spends most of its time on
graph databases and Neo4j.

**Challenges.** PostgreSQL's `jsonb` type sorted the keys of every document, so a booking began
with "channel" and "check_in" instead of the confirmation number. Switching to the plain `json`
type kept the fields in the order I wrote them.

Escaping caught me more than once. A shell command cut one of my SQL files short, and in the
race test the backslashes in my key pattern were stripped twice, so the status line matched
every key in the store instead of three. I only noticed because the output was suddenly huge.
In the end I replaced the pattern with the three exact keys, which is clearer anyway. I also
found out that `similar` is a reserved word in PostgreSQL (from `SIMILAR TO`) when my
recommendation query would not run.

The comparison with PostgreSQL did not come out the way I expected. MongoDB looked slower on
the guest profile until I timed an empty `ping` and saw that the shell itself adds about 2 ms to
every call. The booking screen was slow in PostgreSQL, but the reason was a missing index on
`points_transaction.reservation_id` in my own design, not the relational model.

My first graph query said a member had stayed in 21 countries, which was impossible because no
guest has more than 17 bookings. I had grouped by name, and 900 names in my data belong to more
than one person.

**What I learned.**
* NoSQL is not faster in general. For screens that show one thing, MongoDB and PostgreSQL were
  about the same once I removed the client overhead. For the brand report across a year of
  bookings, PostgreSQL was 13 times faster.
* The document model's real advantage was fewer joins to get wrong. The missing index I found
  could not happen in MongoDB, because the points are inside the booking.
* "Schemaless" does not have to mean no rules. A `$jsonSchema` validator rejected a booking with
  0 nights but still accepted a new optional field.
* The overbooking problem from Portfolio 3 came back in a new form. Reading the count and then
  writing it oversold the last suite every time I tried. Making the check and the change one
  atomic update fixed it.
* Without multi-document transactions, a multi-night booking had to give back the nights it
  had already taken when a later night was full. That made the difference between ACID and BASE
  from Study Session Two concrete for me.
* Graph queries were about three and a half times faster than the same questions in SQL, and much
  easier to read. A shortest path between two guests is one line in Cypher; in SQL I would have
  needed a recursive query.
* A name is not an identifier, whether the data is in a table or a graph.
* I checked the article about Marriott and Couchbase before quoting it. It did not say some of
  the things I had assumed, so I only used what it actually reported.
