-- booking detail screen in PostgreSQL: booking, guest, hotel, room type, payments and points
SELECT r.confirmation_no, g.first_name, g.last_name, h.hotel_name, rt.type_name, r.check_in_date,
       r.check_out_date, r.nightly_rate, r.res_status,
       (SELECT json_agg(p) FROM crs.payment p WHERE p.reservation_id = r.reservation_id) AS payments,
       (SELECT json_agg(t) FROM crs.points_transaction t WHERE t.reservation_id = r.reservation_id) AS points
FROM crs.reservation r
JOIN crs.guest g ON g.guest_id = r.guest_id
JOIN crs.hotel h ON h.hotel_id = r.hotel_id
JOIN crs.room_type rt ON rt.room_type_id = r.room_type_id
WHERE r.confirmation_no = '90485359';
