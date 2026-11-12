-- Portfolio 2: what do the indexes cost when new bookings come in?
-- inserts 50,000 bookings, times it, then rolls back so nothing is kept.
-- run once with the P2 indexes and once without (05_drop_indexes.sql)
-- docker exec marriott_postgres sh -c "psql -U mit8103 -d marriott_crs -f /scripts/p2/06_write_cost.sql 2>&1"

SET search_path TO crs;
BEGIN;
\timing on
INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate,
                         booking_channel, res_status)
SELECT 'W' || g, 100 + g, rt.hotel_id, rt.room_type_id, 1,
       DATE '2027-01-01' + g % 180, DATE '2027-01-01' + g % 180 + 2, 2, rt.base_rate,
       'Web', 'Confirmed'
FROM generate_series(1, 50000) AS g
JOIN room_type rt ON rt.room_type_id = 1 + g % 570;
\timing off
ROLLBACK;
