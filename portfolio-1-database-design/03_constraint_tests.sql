-- =====================================================================
-- MIT 8103 Portfolio 1: Constraint tests
-- Each statement below breaks a business rule on purpose. Every one of
-- them should be REJECTED by the database with an error. The output is
-- saved in evidence/constraint_test_output.txt
--
-- Run:  docker exec -i marriott_postgres psql -U mit8103 -d marriott_crs -f /scripts/p1/03_constraint_tests.sql
-- =====================================================================
SET search_path TO crs;
\echo
\echo '=== Test 1: check-out date before check-in date (CHECK constraint) ==='
INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate, booking_channel)
VALUES ('TEST0001', 1, 1, 1, 1, '2026-12-10', '2026-12-08', 2, 310000, 'Web');

\echo
\echo '=== Test 2: two guests given the same physical room on overlapping nights (EXCLUDE constraint) ==='
-- Room 102 at Accra Marriott is already occupied 8 to 12 Nov 2026 (reservation 84215902).
-- A second Accra booking for 10 to 11 Nov is created, then the front desk tries to
-- put that guest in the same room 102. Everything is rolled back afterwards.
BEGIN;
INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate, booking_channel)
SELECT 'TEST0002', (SELECT guest_id FROM guest WHERE email = 'grace.etim@example.com'),
       rt.hotel_id, rt.room_type_id, 1, '2026-11-10', '2026-11-11', 1, rt.base_rate, 'Walk-in'
FROM room_type rt JOIN hotel h USING (hotel_id)
WHERE h.marsha_code = 'ACCMC' AND rt.type_code = 'DLXK';

INSERT INTO stay (reservation_id, room_id, stay_period)
SELECT (SELECT reservation_id FROM reservation WHERE confirmation_no = 'TEST0002'),
       s.room_id, daterange('2026-11-10', '2026-11-11')
FROM stay s JOIN reservation r ON r.reservation_id = s.reservation_id
WHERE r.confirmation_no = '84215902';
ROLLBACK;

\echo
\echo '=== Test 3: Lagos room pointing at a Dubai room type (composite FOREIGN KEY) ==='
INSERT INTO room (hotel_id, room_type_id, room_number, floor_no)
VALUES ((SELECT hotel_id FROM hotel WHERE marsha_code = 'LOSMC'),
        (SELECT room_type_id FROM room_type rt JOIN hotel h USING (hotel_id)
          WHERE h.marsha_code = 'DXBJW' AND rt.type_code = 'DLXK'),
        '999', 9);

\echo
\echo '=== Test 4: second guest registering with an email that already exists (UNIQUE) ==='
INSERT INTO guest (first_name, last_name, email)
VALUES ('Ada', 'Okafor', 'adaeze.okafor@example.com');

\echo
\echo '=== Test 5: Bonvoy points balance going below zero (CHECK) ==='
UPDATE bonvoy_account SET points_balance = points_balance - 1000000
WHERE member_number = '118230067';

\echo
\echo '=== Test 6: card payment with no card reference (CHECK across two columns) ==='
INSERT INTO payment (reservation_id, amount, currency_code, pay_method)
VALUES (1, 50000, 'NGN', 'Card');

\echo
\echo '=== Test 7: a "Redeem" points transaction that adds points (CHECK) ==='
INSERT INTO points_transaction (account_id, txn_type, points)
VALUES (1, 'Redeem', 5000);

\echo
\echo '=== Test 8: booking a hotel that does not exist (FOREIGN KEY) ==='
INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate, booking_channel)
VALUES ('TEST0008', 1, 999, 1, 1, '2026-12-10', '2026-12-12', 2, 310000, 'Web');

\echo
\echo '=== Test 9: invalid MARSHA code format (CHECK with regular expression) ==='
INSERT INTO hotel (marsha_code, hotel_name, brand_id, city_id, address, star_rating, currency_code)
VALUES ('lag1', 'Test Hotel', 1, 1, 'Somewhere', 5, 'NGN');

\echo
\echo '=== Test 10: checking an Abuja guest into a room in Accra (TRIGGER) ==='
INSERT INTO stay (reservation_id, room_id, stay_period)
SELECT (SELECT reservation_id FROM reservation WHERE confirmation_no = '84218011'),
       (SELECT room_id FROM room rm JOIN hotel h USING (hotel_id)
         WHERE h.marsha_code = 'ACCMC' AND rm.room_number = '101'),
       daterange('2026-12-05', '2026-12-08');

\echo
\echo '=== Control test: the same Accra booking in a DIFFERENT room (101) is accepted ==='
BEGIN;
INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate, booking_channel)
SELECT 'TEST0011', (SELECT guest_id FROM guest WHERE email = 'grace.etim@example.com'),
       rt.hotel_id, rt.room_type_id, 1, '2026-11-10', '2026-11-11', 1, rt.base_rate, 'Walk-in'
FROM room_type rt JOIN hotel h USING (hotel_id)
WHERE h.marsha_code = 'ACCMC' AND rt.type_code = 'DLXK';

INSERT INTO stay (reservation_id, room_id, stay_period)
SELECT (SELECT reservation_id FROM reservation WHERE confirmation_no = 'TEST0011'),
       (SELECT room_id FROM room rm JOIN hotel h USING (hotel_id)
         WHERE h.marsha_code = 'ACCMC' AND rm.room_number = '101'),
       daterange('2026-11-10', '2026-11-11');
ROLLBACK;   -- undo it so the sample data stays clean
\echo '(control insert succeeded and was rolled back)'
