-- One document per booking. Guest, hotel, room type and rate plan are copied in as small
-- snapshots (only the fields a booking screen needs), and payments and points records
-- are embedded because they only ever belong to this one booking.
SET search_path TO crs;

WITH pay AS (
    SELECT reservation_id,
           json_agg(json_strip_nulls(json_build_object(
               'amount', json_build_object('$numberDecimal', amount::text),
               'currency', currency_code,
               'method', pay_method,
               'card_last4', card_last4,
               'status', pay_status,
               'paid_at', json_build_object('$date', to_char(paid_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))))
               ORDER BY paid_at) AS list
    FROM payment GROUP BY reservation_id
), pts AS (
    SELECT reservation_id,
           json_agg(json_build_object('type', txn_type, 'points', points,
               'at', json_build_object('$date', to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')))
               ORDER BY created_at) AS list
    FROM points_transaction WHERE reservation_id IS NOT NULL GROUP BY reservation_id
)
SELECT (json_strip_nulls(json_build_object(
    '_id', r.confirmation_no,
    'guest', json_build_object('id', g.guest_id, 'name', g.first_name || ' ' || g.last_name,
                                'member_number', ba.member_number, 'tier', ba.elite_tier),
    'hotel', json_build_object('code', h.marsha_code, 'name', h.hotel_name, 'city', c.city_name,
                                'brand', b.brand_name),
    'room_type', json_build_object('code', rt.type_code, 'name', rt.type_name),
    'rate_plan', rp.rate_code,
    'check_in', json_build_object('$date', to_char(r.check_in_date, 'YYYY-MM-DD"T00:00:00Z"')),
    'check_out', json_build_object('$date', to_char(r.check_out_date, 'YYYY-MM-DD"T00:00:00Z"')),
    'nights', r.check_out_date - r.check_in_date,
    'guests', r.num_guests,
    'nightly_rate', json_build_object('$numberDecimal', r.nightly_rate::text),
    'currency', h.currency_code,
    'channel', r.booking_channel,
    'status', r.res_status,
    'booked_at', json_build_object('$date', to_char(r.booked_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')),
    'payments', pay.list,
    'points', pts.list
)))::text
FROM reservation r
JOIN guest g USING (guest_id)
LEFT JOIN bonvoy_account ba ON ba.guest_id = g.guest_id
JOIN hotel h ON h.hotel_id = r.hotel_id
JOIN brand b ON b.brand_id = h.brand_id
JOIN city c ON c.city_id = h.city_id
JOIN room_type rt ON rt.room_type_id = r.room_type_id
JOIN rate_plan rp ON rp.rate_plan_id = r.rate_plan_id
LEFT JOIN pay ON pay.reservation_id = r.reservation_id
LEFT JOIN pts ON pts.reservation_id = r.reservation_id;
