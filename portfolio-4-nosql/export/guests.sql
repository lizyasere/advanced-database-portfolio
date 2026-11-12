-- One document per guest. The Bonvoy account is embedded (one to one), and so are the
-- guest's 3 most recent bookings as a short summary. The full booking history stays in
-- the reservations collection, so a guest document can never grow without limit.
SET search_path TO crs;

SELECT (json_strip_nulls(json_build_object(
    '_id', g.guest_id,
    'name', json_build_object('first', g.first_name, 'last', g.last_name),
    'email', g.email,
    'phone', g.phone,
    'nationality', g.nationality,
    'date_of_birth', json_build_object('$date', to_char(g.date_of_birth, 'YYYY-MM-DD"T00:00:00Z"')),
    'created_at', json_build_object('$date', to_char(g.created_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')),
    'bonvoy', CASE WHEN ba.account_id IS NOT NULL THEN json_build_object(
                  'member_number', ba.member_number,
                  'tier', ba.elite_tier,
                  'points_balance', ba.points_balance,
                  'enrolled_on', json_build_object('$date', to_char(ba.enrolled_on, 'YYYY-MM-DD"T00:00:00Z"'))) END,
    'recent_bookings', recent.list
)))::text
FROM guest g
LEFT JOIN bonvoy_account ba ON ba.guest_id = g.guest_id
LEFT JOIN LATERAL (
    SELECT json_agg(json_build_object(
               'confirmation_no', x.confirmation_no,
               'hotel', x.marsha_code,
               'hotel_name', x.hotel_name,
               'check_in', json_build_object('$date', to_char(x.check_in_date, 'YYYY-MM-DD"T00:00:00Z"')),
               'nights', x.check_out_date - x.check_in_date,
               'status', x.res_status) ORDER BY x.check_in_date DESC) AS list
    FROM (SELECT r.confirmation_no, h.marsha_code, h.hotel_name, r.check_in_date, r.check_out_date, r.res_status
          FROM reservation r JOIN hotel h USING (hotel_id)
          WHERE r.guest_id = g.guest_id
          ORDER BY r.check_in_date DESC
          LIMIT 3) x
) recent ON true
ORDER BY g.guest_id;
