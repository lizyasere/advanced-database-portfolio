-- Portfolio 3: puts the demo data back to a known starting point.
-- The runner calls this before every scenario.
--
-- Story: Lagos Marriott Hotel Ikeja has 4 Executive Suites. For Christmas
-- (24 to 27 Dec 2027) three are already booked, so ONE suite is left.
-- Two Bonvoy members are used for the points scenarios.

SET search_path TO crs;

-- two demo members (created once, kept after that)
INSERT INTO guest (first_name, last_name, email, phone, nationality)
VALUES ('Ifeoma', 'Chukwu', 'ifeoma.chukwu@example.com', '+2348034455661', 'NG'),
       ('Daniel', 'Okoro',  'daniel.okoro@example.com',  '+2348055566772', 'NG')
ON CONFLICT DO NOTHING;

INSERT INTO bonvoy_account (guest_id, member_number, elite_tier, points_balance)
SELECT guest_id, v.num, 'Gold Elite', 0
FROM guest g JOIN (VALUES ('ifeoma.chukwu@example.com', '300000001'),
                          ('daniel.okoro@example.com',  '300000002')) v(email, num)
  ON v.email = g.email
ON CONFLICT DO NOTHING;

-- clear anything left by earlier runs
DELETE FROM points_transaction
WHERE account_id IN (SELECT account_id FROM bonvoy_account WHERE member_number IN ('300000001', '300000002'))
   OR reservation_id IN (SELECT reservation_id FROM reservation WHERE confirmation_no LIKE 'P3%');
DELETE FROM payment WHERE reservation_id IN (SELECT reservation_id FROM reservation WHERE confirmation_no LIKE 'P3%');
DELETE FROM reservation WHERE confirmation_no LIKE 'P3%';

-- starting balances
UPDATE bonvoy_account SET points_balance = 50000 WHERE member_number = '300000001';
UPDATE bonvoy_account SET points_balance = 20000 WHERE member_number = '300000002';

-- Executive Suite base rate back to normal (changed by the non-repeatable read demo)
UPDATE room_type SET base_rate = 573500
WHERE type_code = 'EXSU' AND hotel_id = (SELECT hotel_id FROM hotel WHERE marsha_code = 'LOSMC');

-- three of the four Christmas suites already sold
INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate, booking_channel)
SELECT 'P3PRE' || n, (SELECT guest_id FROM guest WHERE email = 'adaeze.okafor@example.com'),
       rt.hotel_id, rt.room_type_id, 1, DATE '2027-12-24', DATE '2027-12-27', 2, rt.base_rate, 'Web'
FROM room_type rt JOIN hotel h USING (hotel_id)
CROSS JOIN generate_series(1, 3) AS n
WHERE h.marsha_code = 'LOSMC' AND rt.type_code = 'EXSU';
