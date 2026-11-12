-- Portfolio 3: adding Bonvoy points safely. The addition happens inside the
-- UPDATE (points_balance = points_balance + x), so the database does the read
-- and the write together while holding the row lock.
-- variables from the runner: who, points

SET search_path TO crs;
BEGIN;
SELECT account_id AS acc FROM bonvoy_account WHERE member_number = '300000001' \gset
\echo [:who] adding :points
UPDATE bonvoy_account SET points_balance = points_balance + :points WHERE account_id = :acc
RETURNING points_balance AS new_balance \gset
\echo [:who] balance is now :new_balance (other session must wait for this row until I commit)
SELECT pg_sleep(2) \g /dev/null
INSERT INTO points_transaction (account_id, txn_type, points) VALUES (:acc, 'Earn', :points);
\echo [:who] committing...
COMMIT;
