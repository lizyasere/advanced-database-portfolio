-- Portfolio 2: the five business queries I am tuning
-- docker exec marriott_postgres sh -c "psql -U mit8103 -d marriott_crs -f /scripts/p2/02_queries.sql 2>&1"

SET search_path TO crs;

\echo '=== Q1 Room availability: Deluxe King at Lagos Marriott Ikeja, 18 to 22 Dec 2026 ==='
-- rooms of that type minus bookings that overlap the dates
SELECT rt.type_name,
       (SELECT count(*) FROM room rm WHERE rm.room_type_id = rt.room_type_id) AS total_rooms,
       (SELECT count(*) FROM reservation r
         WHERE r.room_type_id = rt.room_type_id
           AND r.res_status IN ('Confirmed', 'Checked In')
           AND r.check_in_date < DATE '2026-12-22'
           AND r.check_out_date > DATE '2026-12-18') AS booked
FROM room_type rt
JOIN hotel h ON h.hotel_id = rt.hotel_id
WHERE h.marsha_code = 'LOSMC' AND rt.type_code = 'DLXK';

\echo '=== Q2 Guest lookup by email, typed with different capitals ==='
SELECT g.first_name, g.last_name, r.confirmation_no, h.hotel_name, r.check_in_date, r.res_status
FROM guest g
JOIN reservation r ON r.guest_id = g.guest_id
JOIN hotel h       ON h.hotel_id = r.hotel_id
WHERE lower(g.email) = lower('Adaeze.Okafor@Example.com')
ORDER BY r.check_in_date DESC;

\echo '=== Q3a Monthly revenue for Lagos hotels in 2026 (first version) ==='
SELECT h.hotel_name, date_trunc('month', r.check_in_date)::date AS month,
       count(*) AS bookings,
       sum(r.nightly_rate * (r.check_out_date - r.check_in_date)) AS revenue_ngn
FROM reservation r
JOIN hotel h ON h.hotel_id = r.hotel_id
JOIN city c  ON c.city_id = h.city_id
WHERE c.city_name = 'Lagos'
  AND EXTRACT(YEAR FROM r.check_in_date) = 2026
  AND r.res_status IN ('Checked Out', 'Checked In')
GROUP BY h.hotel_name, month
ORDER BY h.hotel_name, month
LIMIT 15;

\echo '=== Q3b Same report, date filter rewritten as a range ==='
SELECT h.hotel_name, date_trunc('month', r.check_in_date)::date AS month,
       count(*) AS bookings,
       sum(r.nightly_rate * (r.check_out_date - r.check_in_date)) AS revenue_ngn
FROM reservation r
JOIN hotel h ON h.hotel_id = r.hotel_id
JOIN city c  ON c.city_id = h.city_id
WHERE c.city_name = 'Lagos'
  AND r.check_in_date >= DATE '2026-01-01' AND r.check_in_date < DATE '2027-01-01'
  AND r.res_status IN ('Checked Out', 'Checked In')
GROUP BY h.hotel_name, month
ORDER BY h.hotel_name, month
LIMIT 15;

\echo '=== Q4 Front desk arrivals list: Lagos Marriott Ikeja, 12 Nov 2026 ==='
SELECT r.confirmation_no, g.last_name, g.first_name, rt.type_name, r.num_guests,
       COALESCE(ba.elite_tier, 'Not a member') AS bonvoy_tier
FROM reservation r
JOIN hotel h      ON h.hotel_id = r.hotel_id
JOIN guest g      ON g.guest_id = r.guest_id
JOIN room_type rt ON rt.room_type_id = r.room_type_id
LEFT JOIN bonvoy_account ba ON ba.guest_id = g.guest_id
WHERE h.marsha_code = 'LOSMC'
  AND r.check_in_date = DATE '2026-11-12'
  AND r.res_status IN ('Confirmed', 'Checked In')
ORDER BY g.last_name, g.first_name;

\echo '=== Q5 Top 10 Bonvoy members by points earned in the last 12 months ==='
SELECT * FROM (
    SELECT ba.member_number, g.first_name || ' ' || g.last_name AS member, ba.elite_tier,
           sum(pt.points) AS points_earned,
           RANK() OVER (ORDER BY sum(pt.points) DESC) AS position
    FROM points_transaction pt
    JOIN bonvoy_account ba ON ba.account_id = pt.account_id
    JOIN guest g           ON g.guest_id = ba.guest_id
    WHERE pt.txn_type = 'Earn'
      AND pt.created_at >= TIMESTAMPTZ '2025-11-12'
    GROUP BY ba.member_number, g.first_name, g.last_name, ba.elite_tier
) ranked
WHERE position <= 10;

\echo '=== Q5b Same top 10, rewritten: total per account, keep the top 10, then join names ==='
-- WITH TIES keeps anyone tied with 10th place, same as RANK() <= 10
WITH top_earners AS (
    SELECT account_id, sum(points) AS points_earned
    FROM points_transaction
    WHERE txn_type = 'Earn'
      AND created_at >= TIMESTAMPTZ '2025-11-12'
    GROUP BY account_id
    ORDER BY points_earned DESC
    FETCH FIRST 10 ROWS WITH TIES
)
SELECT ba.member_number, g.first_name || ' ' || g.last_name AS member, ba.elite_tier,
       t.points_earned,
       RANK() OVER (ORDER BY t.points_earned DESC) AS position
FROM top_earners t
JOIN bonvoy_account ba ON ba.account_id = t.account_id
JOIN guest g           ON g.guest_id = ba.guest_id
ORDER BY position;
