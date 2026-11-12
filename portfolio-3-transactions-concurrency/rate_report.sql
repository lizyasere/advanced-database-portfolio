-- Portfolio 3: a revenue manager's report reads the suite rate twice in one transaction.
-- variables from the runner: who, iso

SET search_path TO crs;
BEGIN ISOLATION LEVEL :iso;
SELECT base_rate AS r1 FROM room_type JOIN hotel USING (hotel_id)
WHERE marsha_code = 'LOSMC' AND type_code = 'EXSU' \gset
\echo [:who] first read of suite rate: :r1
SELECT pg_sleep(2) \g /dev/null
SELECT base_rate AS r2 FROM room_type JOIN hotel USING (hotel_id)
WHERE marsha_code = 'LOSMC' AND type_code = 'EXSU' \gset
\echo [:who] second read of suite rate: :r2
COMMIT;
