-- Portfolio 3: commit, rollback and savepoints in one session
-- docker exec marriott_postgres sh -c "psql -U mit8103 -d marriott_crs -f /scripts/p3/01_acid_basics.sql 2>&1"
--
-- An award (points) booking touches three tables: reservation, points_transaction
-- and bonvoy_account. Either all three change or none of them do.

\ir 00_reset_demo.sql
SET search_path TO crs;

\echo
\echo '=== 1. Award booking that succeeds (COMMIT) ==='
\echo 'Ifeoma has 50,000 points. 3 nights at Four Points Lagos cost 36,000 points.'
SELECT member_number, points_balance FROM bonvoy_account WHERE member_number = '300000001';

BEGIN;
INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate, booking_channel)
SELECT 'P3AWARD1', g.guest_id, rt.hotel_id, rt.room_type_id, rp.rate_plan_id,
       DATE '2027-12-10', DATE '2027-12-13', 1, 0, 'Mobile App'
FROM guest g, room_type rt JOIN hotel h USING (hotel_id), rate_plan rp
WHERE g.email = 'ifeoma.chukwu@example.com' AND h.marsha_code = 'LOSFP'
  AND rt.type_code = 'DLXK' AND rp.rate_code = 'POINTS';
INSERT INTO points_transaction (account_id, reservation_id, txn_type, points)
SELECT a.account_id, r.reservation_id, 'Redeem', -36000
FROM bonvoy_account a, reservation r
WHERE a.member_number = '300000001' AND r.confirmation_no = 'P3AWARD1';
UPDATE bonvoy_account SET points_balance = points_balance - 36000 WHERE member_number = '300000001';
COMMIT;

SELECT member_number, points_balance FROM bonvoy_account WHERE member_number = '300000001';
SELECT confirmation_no, res_status FROM reservation WHERE confirmation_no = 'P3AWARD1';

\echo
\echo '=== 2. Award booking that fails part way (automatic ROLLBACK) ==='
\echo 'Daniel has only 20,000 points but tries the same 36,000 point stay.'
\echo 'The booking and the points record insert fine, then the balance update breaks'
\echo 'the CHECK (points_balance >= 0) rule, so the whole transaction is cancelled.'
SELECT member_number, points_balance FROM bonvoy_account WHERE member_number = '300000002';

BEGIN;
INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate, booking_channel)
SELECT 'P3AWARD2', g.guest_id, rt.hotel_id, rt.room_type_id, rp.rate_plan_id,
       DATE '2027-12-10', DATE '2027-12-13', 1, 0, 'Mobile App'
FROM guest g, room_type rt JOIN hotel h USING (hotel_id), rate_plan rp
WHERE g.email = 'daniel.okoro@example.com' AND h.marsha_code = 'LOSFP'
  AND rt.type_code = 'DLXK' AND rp.rate_code = 'POINTS';
INSERT INTO points_transaction (account_id, reservation_id, txn_type, points)
SELECT a.account_id, r.reservation_id, 'Redeem', -36000
FROM bonvoy_account a, reservation r
WHERE a.member_number = '300000002' AND r.confirmation_no = 'P3AWARD2';
UPDATE bonvoy_account SET points_balance = points_balance - 36000 WHERE member_number = '300000002';
COMMIT;   -- after an error PostgreSQL turns this into ROLLBACK

\echo 'After the failed transaction: no booking, no points record, balance unchanged'
SELECT count(*) AS bookings_named_P3AWARD2 FROM reservation WHERE confirmation_no = 'P3AWARD2';
SELECT count(*) AS points_records_for_daniel FROM points_transaction pt
JOIN bonvoy_account a USING (account_id) WHERE a.member_number = '300000002';
SELECT member_number, points_balance FROM bonvoy_account WHERE member_number = '300000002';

\echo
\echo '=== 3. Guest closes the app before paying (explicit ROLLBACK) ==='
BEGIN;
INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate, booking_channel)
SELECT 'P3ABANDON', g.guest_id, rt.hotel_id, rt.room_type_id, 1,
       DATE '2027-11-05', DATE '2027-11-07', 2, rt.base_rate, 'Mobile App'
FROM guest g, room_type rt JOIN hotel h USING (hotel_id)
WHERE g.email = 'daniel.okoro@example.com' AND h.marsha_code = 'ABVSI' AND rt.type_code = 'DLXT';
SELECT confirmation_no, res_status FROM reservation WHERE confirmation_no = 'P3ABANDON';
ROLLBACK;
SELECT count(*) AS bookings_named_P3ABANDON FROM reservation WHERE confirmation_no = 'P3ABANDON';

\echo
\echo '=== 4. Savepoint: keep the booking, undo only the bad payment ==='
\echo 'The booking is saved, then a card payment is entered without the card digits.'
\echo 'Rolling back to the savepoint removes only the bad payment; a correct one is added.'
BEGIN;
INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                         check_in_date, check_out_date, num_guests, nightly_rate, booking_channel)
SELECT 'P3SAVE1', g.guest_id, rt.hotel_id, rt.room_type_id, 1,
       DATE '2027-11-05', DATE '2027-11-07', 2, rt.base_rate, 'Call Centre'
FROM guest g, room_type rt JOIN hotel h USING (hotel_id)
WHERE g.email = 'daniel.okoro@example.com' AND h.marsha_code = 'ABVSI' AND rt.type_code = 'DLXT';
SAVEPOINT before_payment;
INSERT INTO payment (reservation_id, amount, currency_code, pay_method)
SELECT reservation_id, nightly_rate * 2, 'NGN', 'Card' FROM reservation WHERE confirmation_no = 'P3SAVE1';
ROLLBACK TO SAVEPOINT before_payment;
INSERT INTO payment (reservation_id, amount, currency_code, pay_method, card_last4)
SELECT reservation_id, nightly_rate * 2, 'NGN', 'Card', '4417' FROM reservation WHERE confirmation_no = 'P3SAVE1';
COMMIT;

SELECT r.confirmation_no, p.amount, p.pay_method, p.card_last4
FROM reservation r JOIN payment p USING (reservation_id) WHERE r.confirmation_no = 'P3SAVE1';
