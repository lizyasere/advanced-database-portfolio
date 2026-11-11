-- =====================================================================
-- MIT 8103 Portfolio 1: Quick checks that the data loaded correctly
-- Run:  docker exec -i marriott_postgres psql -U mit8103 -d marriott_crs -f /scripts/p1/04_verify_data.sql
-- =====================================================================
SET search_path TO crs;

\echo '=== Row count per table ==='
SELECT 'country' AS table_name, count(*) FROM country UNION ALL
SELECT 'city', count(*) FROM city UNION ALL
SELECT 'brand', count(*) FROM brand UNION ALL
SELECT 'hotel', count(*) FROM hotel UNION ALL
SELECT 'staff', count(*) FROM staff UNION ALL
SELECT 'room_type', count(*) FROM room_type UNION ALL
SELECT 'room', count(*) FROM room UNION ALL
SELECT 'rate_plan', count(*) FROM rate_plan UNION ALL
SELECT 'guest', count(*) FROM guest UNION ALL
SELECT 'bonvoy_account', count(*) FROM bonvoy_account UNION ALL
SELECT 'reservation', count(*) FROM reservation UNION ALL
SELECT 'stay', count(*) FROM stay UNION ALL
SELECT 'payment', count(*) FROM payment UNION ALL
SELECT 'points_transaction', count(*) FROM points_transaction UNION ALL
SELECT 'review', count(*) FROM review;

\echo '=== Hotels with brand, tier and location ==='
SELECT h.marsha_code, h.hotel_name, b.brand_name, b.tier, c.city_name, co.country_name
FROM hotel h
JOIN brand b    ON b.brand_id = h.brand_id
JOIN city c     ON c.city_id = h.city_id
JOIN country co ON co.country_code = c.country_code
ORDER BY co.region, c.city_name;

\echo '=== Reservations with guest, hotel, room type and total cost ==='
SELECT r.confirmation_no, g.first_name || ' ' || g.last_name AS guest,
       h.marsha_code, rt.type_name, rp.rate_code,
       r.check_in_date, r.check_out_date - r.check_in_date AS nights,
       h.currency_code || ' ' || to_char(r.nightly_rate * (r.check_out_date - r.check_in_date), 'FM999,999,990.00') AS total,
       r.res_status
FROM reservation r
JOIN guest g      ON g.guest_id = r.guest_id
JOIN hotel h      ON h.hotel_id = r.hotel_id
JOIN room_type rt ON rt.room_type_id = r.room_type_id
JOIN rate_plan rp ON rp.rate_plan_id = r.rate_plan_id
ORDER BY r.check_in_date;
