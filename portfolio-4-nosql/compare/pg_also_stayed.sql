-- "guests who stayed at LOSMC also stayed at", in SQL: the reservation table joined to itself
\timing on
SELECT h2.marsha_code, h2.hotel_name, count(DISTINCT r2.guest_id) AS shared_guests
FROM crs.reservation r1
JOIN crs.hotel h1 ON h1.hotel_id = r1.hotel_id
JOIN crs.reservation r2 ON r2.guest_id = r1.guest_id AND r2.hotel_id <> r1.hotel_id
                       AND r2.res_status = 'Checked Out'
JOIN crs.hotel h2 ON h2.hotel_id = r2.hotel_id
WHERE h1.marsha_code = 'LOSMC' AND r1.res_status = 'Checked Out'
GROUP BY h2.marsha_code, h2.hotel_name
ORDER BY shared_guests DESC LIMIT 5;
