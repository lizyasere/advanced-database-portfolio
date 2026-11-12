-- Portfolio 2: bulk data so the query plans mean something
-- run after the Portfolio 1 scripts. Takes about a minute.
-- docker exec marriott_postgres psql -U mit8103 -d marriott_crs -f /scripts/p2/01_generate_data.sql

SET search_path TO crs;
SELECT setseed(0.2026);   -- same random data every run

-- more countries
INSERT INTO country (country_code, country_name, region) VALUES
 ('KE', 'Kenya', 'Africa'), ('EG', 'Egypt', 'Africa'), ('MA', 'Morocco', 'Africa'),
 ('SA', 'Saudi Arabia', 'Middle East'),
 ('FR', 'France', 'Europe'), ('DE', 'Germany', 'Europe'), ('ES', 'Spain', 'Europe'), ('IT', 'Italy', 'Europe'),
 ('CA', 'Canada', 'US & Canada'),
 ('CN', 'China', 'Asia Pacific'), ('JP', 'Japan', 'Asia Pacific'), ('SG', 'Singapore', 'Asia Pacific'), ('IN', 'India', 'Asia Pacific'),
 ('BR', 'Brazil', 'Caribbean & Latin America'), ('MX', 'Mexico', 'Caribbean & Latin America')
ON CONFLICT DO NOTHING;

-- cities, local currency, rough deluxe room price and how many hotels to create there
CREATE TEMP TABLE city_seed (city_name text, country_code char(2), currency char(3), deluxe_rate numeric, hotels int);
INSERT INTO city_seed VALUES
 ('Lagos', 'NG', 'NGN', 240000, 12), ('Abuja', 'NG', 'NGN', 220000, 6), ('Port Harcourt', 'NG', 'NGN', 180000, 3),
 ('Accra', 'GH', 'GHS', 3200, 4), ('Kumasi', 'GH', 'GHS', 2200, 1), ('Nairobi', 'KE', 'KES', 22000, 5),
 ('Johannesburg', 'ZA', 'ZAR', 2900, 6), ('Cape Town', 'ZA', 'ZAR', 3400, 5), ('Cairo', 'EG', 'EGP', 7500, 5),
 ('Marrakech', 'MA', 'MAD', 2600, 3), ('Dubai', 'AE', 'AED', 850, 12), ('Abu Dhabi', 'AE', 'AED', 700, 5),
 ('Riyadh', 'SA', 'SAR', 900, 6), ('London', 'GB', 'GBP', 320, 14), ('Manchester', 'GB', 'GBP', 160, 4),
 ('Edinburgh', 'GB', 'GBP', 190, 3), ('Paris', 'FR', 'EUR', 380, 9), ('Berlin', 'DE', 'EUR', 210, 5),
 ('Madrid', 'ES', 'EUR', 230, 4), ('Rome', 'IT', 'EUR', 300, 4), ('New York', 'US', 'USD', 389, 15),
 ('Chicago', 'US', 'USD', 260, 7), ('Atlanta', 'US', 'USD', 210, 6), ('Houston', 'US', 'USD', 190, 5),
 ('Los Angeles', 'US', 'USD', 280, 7), ('Miami', 'US', 'USD', 310, 5), ('Toronto', 'CA', 'CAD', 330, 4),
 ('Shanghai', 'CN', 'CNY', 1500, 6), ('Tokyo', 'JP', 'JPY', 42000, 5), ('Singapore', 'SG', 'SGD', 420, 4),
 ('Mumbai', 'IN', 'INR', 14000, 4), ('Sao Paulo', 'BR', 'BRL', 750, 3), ('Cancun', 'MX', 'MXN', 4800, 3);

INSERT INTO city (city_name, country_code)
SELECT city_name, country_code FROM city_seed
ON CONFLICT DO NOTHING;

-- 190 more hotels (198 in total). Codes start with Q so they never clash with real ones.
INSERT INTO hotel (marsha_code, hotel_name, brand_id, city_id, address, star_rating, currency_code, opened_on)
SELECT 'Q' || chr(65 + (k / 17576) % 26) || chr(65 + (k / 676) % 26) || chr(65 + (k / 26) % 26) || chr(65 + k % 26),
       b.brand_name || ' ' || s.city_name || ' ' ||
         (ARRAY['Airport', 'City Centre', 'Downtown', 'Waterfront', 'Central', 'North', 'Business District', 'Riverside'])[1 + k % 8],
       b.brand_id, c.city_id,
       (10 + k * 7) || ' ' || (ARRAY['Marina Road', 'King Street', 'Park Avenue', 'Station Road', 'Harbour Drive', 'Main Street'])[1 + k % 6],
       CASE b.tier WHEN 'Luxury' THEN 5 WHEN 'Premium' THEN 4 + (k % 2) ELSE 3 + (k % 2) END,
       s.currency,
       DATE '1980-01-01' + (k * 97 % 15000)
FROM (
    SELECT s.*, (row_number() OVER (ORDER BY s.city_name, n))::int AS k
    FROM city_seed s CROSS JOIN LATERAL generate_series(1, s.hotels) AS n
) s
JOIN city c  ON c.city_name = s.city_name AND c.country_code = s.country_code
JOIN brand b ON b.brand_id = (SELECT brand_id FROM brand ORDER BY brand_id OFFSET (s.k * 5 % 8) LIMIT 1);

-- room types for the new hotels, priced around the city's usual rate
INSERT INTO room_type (hotel_id, type_code, type_name, bed_type, max_occupancy, base_rate)
SELECT h.hotel_id, t.code, t.name, t.bed, t.occ, round((s.deluxe_rate * (0.8 + random() * 0.5) * t.factor)::numeric, 2)
FROM hotel h
JOIN city c       ON c.city_id = h.city_id
JOIN city_seed s  ON s.city_name = c.city_name AND s.country_code = c.country_code
CROSS JOIN (VALUES ('DLXK', 'Deluxe King', 'King', 2, 1.00),
                   ('DLXT', 'Deluxe Twin', 'Twin', 3, 1.00),
                   ('EXSU', 'Executive Suite', 'King', 4, 1.85)) AS t(code, name, bed, occ, factor)
WHERE h.marsha_code LIKE 'Q%';

-- 120 to 300 rooms per new hotel, 30 per floor. 50% king, 40% twin, 10% suites
INSERT INTO room (hotel_id, room_type_id, room_number, floor_no)
SELECT h.hotel_id, rt.room_type_id,
       ((1 + (n - 1) / 30) * 100 + ((n - 1) % 30) + 1)::text,
       1 + (n - 1) / 30
FROM (SELECT hotel_id, 120 + floor(random() * 181)::int AS room_count
      FROM hotel WHERE marsha_code LIKE 'Q%') h
CROSS JOIN LATERAL generate_series(1, h.room_count) AS n
JOIN room_type rt ON rt.hotel_id = h.hotel_id
                 AND rt.type_code = CASE WHEN n % 10 < 5 THEN 'DLXK' WHEN n % 10 < 9 THEN 'DLXT' ELSE 'EXSU' END;

-- 200,000 guests. Emails keep the capital letters people type, which matters for query 2.
INSERT INTO guest (first_name, last_name, email, phone, nationality, date_of_birth, created_at)
SELECT fn, ln,
       fn || '.' || ln || g || '@' || (ARRAY['example.com', 'example.org', 'example.net'])[1 + g % 3],
       '+' || (2340000000000 + floor(random() * 9999999999))::bigint,
       (ARRAY['NG','NG','NG','NG','GH','KE','ZA','AE','GB','GB','US','US','US','FR','DE','IN','CN','CA'])[1 + floor(random() * 18)::int],
       DATE '1950-01-01' + floor(random() * 19000)::int,
       TIMESTAMPTZ '2015-01-01' + random() * INTERVAL '4000 days'
FROM (
    SELECT g,
           (ARRAY['Adaeze','Chinedu','Ngozi','Tunde','Bola','Emeka','Fatima','Ibrahim','Aisha','Kemi',
                  'Segun','Amaka','Yusuf','Halima','Kwame','Ama','Wanjiru','Thabo','Sarah','James',
                  'Michael','Emily','David','Sophie','Omar','Layla','Wei','Yuki','Priya','Carlos'])[1 + floor(random() * 30)::int] AS fn,
           (ARRAY['Okafor','Adeyemi','Bello','Eze','Okonkwo','Nwosu','Abubakar','Musa','Ogunleye','Etim',
                  'Balogun','Obi','Mensah','Boateng','Kamau','Dlamini','Smith','Johnson','Brown','Williams',
                  'Taylor','Martin','Haddad','Rahman','Chen','Tanaka','Patel','Garcia','Silva','Muller'])[1 + floor(random() * 30)::int] AS ln
    FROM generate_series(1, 200000) AS g
) x;

-- about 60% of guests join Bonvoy
INSERT INTO bonvoy_account (guest_id, member_number, elite_tier, points_balance, enrolled_on)
SELECT guest_id,
       (200000000 + guest_id)::text,
       CASE WHEN r < 0.55 THEN 'Member' WHEN r < 0.75 THEN 'Silver Elite' WHEN r < 0.88 THEN 'Gold Elite'
            WHEN r < 0.96 THEN 'Platinum Elite' WHEN r < 0.99 THEN 'Titanium Elite' ELSE 'Ambassador Elite' END,
       floor(random() * 250000)::int,
       created_at::date
FROM (SELECT guest_id, created_at, random() AS r, random() AS pick
      FROM guest WHERE guest_id NOT IN (SELECT guest_id FROM bonvoy_account)) g
WHERE pick < 0.6;

-- 1,000,000 reservations from Jan 2024 to Jun 2027. "Today" is fixed at 12 Nov 2026
-- so the statuses come out the same every time the script runs.
CREATE TEMP TABLE id_pool AS
SELECT (SELECT array_agg(guest_id ORDER BY guest_id) FROM guest) AS guests,
       (SELECT array_agg(room_type_id ORDER BY room_type_id) FROM room_type) AS room_types;

INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate,
                         booking_channel, res_status, booked_at)
WITH base AS MATERIALIZED (
    SELECT g,
           p.guests[1 + floor(random() * cardinality(p.guests))::int] AS guest_id,
           p.room_types[1 + floor(random() * cardinality(p.room_types))::int] AS room_type_id,
           random() AS rp_r,
           DATE '2024-01-01' + floor(random() * (DATE '2027-06-30' - DATE '2024-01-01'))::int AS cin,
           (ARRAY[1, 1, 2, 2, 2, 3, 3, 4, 5, 7])[1 + floor(random() * 10)::int] AS nights,
           floor(random() * 120)::int AS lead_days,
           random() AS st_r,
           (ARRAY['Web','Web','Web','Mobile App','Mobile App','Mobile App','Call Centre','Travel Agent','Travel Agent','Walk-in'])[1 + floor(random() * 10)::int] AS channel,
           1 + floor(random() * 2)::int AS pax
    FROM generate_series(1, 1000000) AS g, id_pool p
),
priced AS (
    SELECT b.*, rt.hotel_id, rt.base_rate,
           -- members only rates fall back to the flexible rate for non members
           CASE WHEN b.rp_r < 0.35 THEN 'FLEX'
                WHEN b.rp_r < 0.65 THEN CASE WHEN ba.account_id IS NULL THEN 'FLEX' ELSE 'MEMBER' END
                WHEN b.rp_r < 0.85 THEN 'ADVPUR'
                WHEN b.rp_r < 0.97 THEN 'CORP'
                ELSE CASE WHEN ba.account_id IS NULL THEN 'FLEX' ELSE 'POINTS' END
           END AS rate_code
    FROM base b
    JOIN room_type rt ON rt.room_type_id = b.room_type_id
    LEFT JOIN bonvoy_account ba ON ba.guest_id = b.guest_id
)
SELECT (90000000 + p.g)::text, p.guest_id, p.hotel_id, p.room_type_id, rp.rate_plan_id,
       p.cin, p.cin + p.nights, p.pax,
       round(p.base_rate * (1 - rp.discount_pct / 100), 2),
       CASE WHEN p.channel = 'Walk-in' AND p.cin > DATE '2026-11-12' THEN 'Web' ELSE p.channel END,
       CASE WHEN p.cin + p.nights <= DATE '2026-11-12' THEN
                 CASE WHEN p.st_r < 0.08 THEN 'Cancelled' WHEN p.st_r < 0.11 THEN 'No Show' ELSE 'Checked Out' END
            WHEN p.cin <= DATE '2026-11-12' THEN
                 CASE WHEN p.st_r < 0.05 THEN 'Cancelled' ELSE 'Checked In' END
            ELSE CASE WHEN p.st_r < 0.12 THEN 'Cancelled' ELSE 'Confirmed' END
       END,
       (p.cin - p.lead_days) + random() * INTERVAL '1 day'
FROM priced p
JOIN rate_plan rp ON rp.rate_code = p.rate_code;

-- payments for completed and current stays
INSERT INTO payment (reservation_id, amount, currency_code, pay_method, card_last4, pay_status, paid_at)
SELECT r.reservation_id,
       r.nightly_rate * (r.check_out_date - r.check_in_date),
       h.currency_code, m.method,
       CASE WHEN m.method = 'Card' THEN lpad(floor(random() * 10000)::int::text, 4, '0') END,
       CASE WHEN r.res_status = 'Checked Out' THEN 'Captured' ELSE 'Authorised' END,
       CASE WHEN r.res_status = 'Checked Out' THEN r.check_out_date + TIME '10:30'
            ELSE r.check_in_date + TIME '15:00' END
FROM reservation r
JOIN hotel h ON h.hotel_id = r.hotel_id
CROSS JOIN LATERAL (
    SELECT (ARRAY['Card','Card','Card','Card','Card','Bank Transfer','Corporate','Cash'])[1 + floor(random() * 8)::int] AS method
    WHERE r.reservation_id IS NOT NULL   -- ties it to each row so a new method is picked per payment
) m
WHERE r.res_status IN ('Checked Out', 'Checked In')
  AND r.nightly_rate > 0
  AND r.confirmation_no LIKE '9%';

-- points earned after checkout (members only), and points spent on award stays
INSERT INTO points_transaction (account_id, reservation_id, txn_type, points, created_at)
SELECT ba.account_id, r.reservation_id, 'Earn',
       (r.check_out_date - r.check_in_date) * (800 + floor(random() * 1200)::int),
       r.check_out_date + INTERVAL '1 day 2 hours'
FROM reservation r
JOIN bonvoy_account ba ON ba.guest_id = r.guest_id
JOIN rate_plan rp      ON rp.rate_plan_id = r.rate_plan_id
WHERE r.res_status = 'Checked Out' AND rp.rate_code <> 'POINTS' AND r.confirmation_no LIKE '9%';

INSERT INTO points_transaction (account_id, reservation_id, txn_type, points, created_at)
SELECT ba.account_id, r.reservation_id, 'Redeem',
       -(r.check_out_date - r.check_in_date) * 35000,
       r.booked_at
FROM reservation r
JOIN bonvoy_account ba ON ba.guest_id = r.guest_id
JOIN rate_plan rp      ON rp.rate_plan_id = r.rate_plan_id
WHERE rp.rate_code = 'POINTS' AND r.res_status <> 'Cancelled' AND r.confirmation_no LIKE '9%';

-- refresh planner statistics after the big load
VACUUM ANALYZE;

SELECT 'hotel' AS table_name, count(*) FROM hotel UNION ALL
SELECT 'room', count(*) FROM room UNION ALL
SELECT 'guest', count(*) FROM guest UNION ALL
SELECT 'bonvoy_account', count(*) FROM bonvoy_account UNION ALL
SELECT 'reservation', count(*) FROM reservation UNION ALL
SELECT 'payment', count(*) FROM payment UNION ALL
SELECT 'points_transaction', count(*) FROM points_transaction;
