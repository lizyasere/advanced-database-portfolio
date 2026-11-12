-- Portfolio 3: booking the last Christmas suite, the safe way.
-- Same steps as book_suite_unsafe.sql, but first it locks the room type row
-- with SELECT ... FOR UPDATE. A second booking for the same room type has to
-- wait here until the first one commits, and then it sees the new booking.
-- variables from the runner: who, conf, email

SET search_path TO crs;
SELECT room_type_id AS rt FROM room_type JOIN hotel USING (hotel_id)
WHERE marsha_code = 'LOSMC' AND type_code = 'EXSU' \gset

BEGIN;   -- default READ COMMITTED
\echo [:who] locking the Executive Suite inventory...
SELECT room_type_id FROM room_type WHERE room_type_id = :rt FOR UPDATE \g /dev/null
\echo [:who] got the lock, checking availability...
SELECT (SELECT count(*) FROM room WHERE room_type_id = :rt)
     - (SELECT count(*) FROM reservation
         WHERE room_type_id = :rt AND res_status IN ('Confirmed', 'Checked In')
           AND check_in_date < DATE '2027-12-27' AND check_out_date > DATE '2027-12-24') AS rooms_free \gset
\echo [:who] suites free: :rooms_free
SELECT :rooms_free > 0 AS can_book \gset

\if :can_book
    \echo [:who] guest is paying...
    SELECT pg_sleep(2) \g /dev/null
    INSERT INTO reservation (confirmation_no, guest_id, hotel_id, room_type_id, rate_plan_id,
                             check_in_date, check_out_date, num_guests, nightly_rate, booking_channel)
    SELECT :'conf', g.guest_id, rt.hotel_id, rt.room_type_id, 1,
           DATE '2027-12-24', DATE '2027-12-27', 2, rt.base_rate, 'Web'
    FROM guest g, room_type rt
    WHERE g.email = :'email' AND rt.room_type_id = :rt;
    \echo [:who] committing...
    COMMIT;
\else
    \echo [:who] sold out, booking refused
    ROLLBACK;
\endif
