-- room nights by brand, last 12 months, in PostgreSQL
SELECT b.brand_name, count(*) AS stays, sum(r.check_out_date - r.check_in_date) AS room_nights
FROM crs.reservation r
JOIN crs.hotel h ON h.hotel_id = r.hotel_id
JOIN crs.brand b ON b.brand_id = h.brand_id
WHERE r.res_status = 'Checked Out'
  AND r.check_in_date >= DATE '2025-11-12' AND r.check_in_date < DATE '2026-11-12'
GROUP BY b.brand_name ORDER BY room_nights DESC;
