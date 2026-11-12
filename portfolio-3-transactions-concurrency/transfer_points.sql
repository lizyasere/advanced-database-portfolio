-- Portfolio 3: Bonvoy lets members transfer points to each other.
-- This version updates the sender first, then the receiver.
-- variables from the runner: who, from_member, to_member, points

SET search_path TO crs;
BEGIN;
\echo [:who] taking :points points from :from_member
UPDATE bonvoy_account SET points_balance = points_balance - :points WHERE member_number = :'from_member';
SELECT pg_sleep(1) \g /dev/null
\echo [:who] giving :points points to :to_member
UPDATE bonvoy_account SET points_balance = points_balance + :points WHERE member_number = :'to_member';
\echo [:who] committing...
COMMIT;
