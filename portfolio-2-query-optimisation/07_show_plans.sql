-- Portfolio 2: short version of the plans for Q1, Q2 and Q4, for screenshots
-- docker exec marriott_postgres sh -c "psql -U mit8103 -d marriott_crs -f /scripts/p2/07_show_plans.sql 2>&1"

SET search_path TO crs;

\echo '=== Q1 Room availability ==='
EXPLAIN (ANALYZE, COSTS OFF)
SELECT count(*) FROM reservation r
WHERE r.room_type_id = (SELECT rt.room_type_id FROM room_type rt JOIN hotel h USING (hotel_id)
                         WHERE h.marsha_code = 'LOSMC' AND rt.type_code = 'DLXK')
  AND r.res_status IN ('Confirmed', 'Checked In')
  AND r.check_in_date < DATE '2026-12-22'
  AND r.check_out_date > DATE '2026-12-18';

\echo '=== Q2 Guest lookup by email ==='
EXPLAIN (ANALYZE, COSTS OFF)
SELECT guest_id, first_name, last_name FROM guest
WHERE lower(email) = lower('Adaeze.Okafor@Example.com');

\echo '=== Q4 Arrivals today at Lagos Marriott Ikeja ==='
EXPLAIN (ANALYZE, COSTS OFF)
SELECT confirmation_no, guest_id FROM reservation
WHERE hotel_id = (SELECT hotel_id FROM hotel WHERE marsha_code = 'LOSMC')
  AND check_in_date = DATE '2026-11-12'
  AND res_status IN ('Confirmed', 'Checked In');
