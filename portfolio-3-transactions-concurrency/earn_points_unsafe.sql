-- Portfolio 3: adding Bonvoy points the naive way (read, add in the app, write back).
-- variables from the runner: who, iso, points

SET search_path TO crs;
BEGIN ISOLATION LEVEL :iso;
SELECT account_id AS acc, points_balance AS bal FROM bonvoy_account WHERE member_number = '300000001' \gset
\echo [:who] read balance: :bal, adding :points
SELECT pg_sleep(2) \g /dev/null
UPDATE bonvoy_account SET points_balance = :bal + :points WHERE account_id = :acc;
INSERT INTO points_transaction (account_id, txn_type, points) VALUES (:acc, 'Earn', :points);
\echo [:who] committing...
COMMIT;
