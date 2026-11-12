-- Portfolio 3: another user raises the Christmas suite rate while the report is running.
-- variables from the runner: who

SET search_path TO crs;
\echo [:who] raising the suite rate to 650000
UPDATE room_type SET base_rate = 650000
WHERE type_code = 'EXSU' AND hotel_id = (SELECT hotel_id FROM hotel WHERE marsha_code = 'LOSMC');
\echo [:who] committed (autocommit)
