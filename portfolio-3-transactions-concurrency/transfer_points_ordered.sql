-- Portfolio 3: the same transfer, but both accounts are locked first,
-- always in member number order. Two transfers can no longer lock the
-- rows in opposite orders, so they cannot deadlock. One simply waits.
-- variables from the runner: who, from_member, to_member, points

SET search_path TO crs;
BEGIN;
\echo [:who] locking both accounts in member number order...
SELECT member_number FROM bonvoy_account
WHERE member_number IN (:'from_member', :'to_member')
ORDER BY member_number
FOR UPDATE \g /dev/null
\echo [:who] got both locks, taking :points points from :from_member
UPDATE bonvoy_account SET points_balance = points_balance - :points WHERE member_number = :'from_member';
SELECT pg_sleep(1) \g /dev/null
\echo [:who] giving :points points to :to_member
UPDATE bonvoy_account SET points_balance = points_balance + :points WHERE member_number = :'to_member';
\echo [:who] committing...
COMMIT;
