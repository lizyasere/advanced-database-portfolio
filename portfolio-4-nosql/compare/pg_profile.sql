-- guest profile screen in PostgreSQL: three tables joined
SELECT g.guest_id, g.first_name, g.last_name, g.email, g.phone, ba.member_number, ba.elite_tier,
       ba.points_balance, r.confirmation_no, h.marsha_code, h.hotel_name, r.check_in_date,
       r.check_out_date - r.check_in_date AS nights, r.res_status
FROM crs.guest g
LEFT JOIN crs.bonvoy_account ba ON ba.guest_id = g.guest_id
LEFT JOIN LATERAL (SELECT * FROM crs.reservation x WHERE x.guest_id = g.guest_id
                   ORDER BY x.check_in_date DESC LIMIT 3) r ON true
LEFT JOIN crs.hotel h ON h.hotel_id = r.hotel_id
WHERE g.email = 'Layla.Chen63452@example.net';
